import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/app_config.dart';

class AuthService extends ChangeNotifier {
  static String get baseUrl => AppConfig.baseUrl;

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      resetOnError: true,
    ),
  );

  String? _token;
  String? _myrabaHandle;
  String? _myrabaTag;   // "m₦Davinci96"
  String? _role;
  String? _fullName;
  String  _kycStatus = 'NONE'; // NONE | PENDING | APPROVED | REJECTED

  String? get token        => _token;
  String? get myrabaHandle => _myrabaHandle;
  String? get myrabaTag    => _myrabaTag ?? (_myrabaHandle != null ? 'v\u20a6$_myrabaHandle' : null);
  String? get role         => _role;
  String? get fullName     => _fullName;
  String  get kycStatus    => _kycStatus;
  bool    get isLoggedIn   => _token != null;
  bool    get isAdmin      => _role == 'ADMIN' || _role == 'SUPER_ADMIN' || _role == 'STAFF';
  bool    get isKycApproved => _kycStatus == 'APPROVED';

  void updateKycStatus(String status) {
    if (_kycStatus != status) {
      _kycStatus = status;
      notifyListeners();
    }
  }

  AuthService() { loadToken(); }

  Future<void> loadToken() async {
    _token      = await _storage.read(key: 'jwt');
    _myrabaHandle = await _storage.read(key: 'handle');
    _myrabaTag   = await _storage.read(key: 'myrabaTag');
    _role       = await _storage.read(key: 'role');
    _fullName   = await _storage.read(key: 'fullName');
    if (_token != null) notifyListeners();
  }

  /// Login with phone number or email
  Future<String?> login(String identifier, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'identifier': identifier.trim(), 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _saveSession(data);
        notifyListeners();
        return null; // null = success
      }

      final error = jsonDecode(response.body);
      return error['message'] ?? 'Login failed. Please try again.';
    } catch (_) {
      return 'Cannot reach server. Check your connection.';
    }
  }

  /// Send OTP to phone or email before registration
  Future<String?> sendOtp(String contact, {String purpose = 'REGISTRATION'}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/send-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'contact': contact.trim(), 'purpose': purpose}),
      );
      if (response.statusCode == 200) return null;
      return jsonDecode(response.body)['message'] ?? 'Failed to send OTP';
    } catch (_) {
      return 'Cannot reach server. Check your connection.';
    }
  }

  /// Register a new user
  Future<String?> register({
    required String myrabaHandle,
    required String password,
    required String fullName,
    required String phone,
    String? email,
    required String otpCode,
    String? otpContact,
    String? customAccountId,
    String? referralCode,
    String? gender,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'myrabaHandle': myrabaHandle.trim(),
          'password': password,
          'fullName': fullName.trim(),
          'phone': phone.trim(),
          if (email != null && email.isNotEmpty) 'email': email.trim(),
          'otpCode': otpCode.trim(),
          if (otpContact != null && otpContact.isNotEmpty) 'otpContact': otpContact.trim(),
          if (customAccountId != null && customAccountId.isNotEmpty) 'customAccountId': customAccountId.trim(),
          if (referralCode != null && referralCode.isNotEmpty) 'referralCode': referralCode,
          if (gender != null && gender.isNotEmpty) 'gender': gender,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        await _saveSession(data);
        notifyListeners();
        return null;
      }

      final error = jsonDecode(response.body);
      return error['message'] ?? 'Registration failed.';
    } catch (_) {
      return 'Cannot reach server. Check your connection.';
    }
  }

  Future<String?> resetPassword({
    required String contact,
    required String otpCode,
    required String newPassword,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contact': contact.trim(),
          'otpCode': otpCode.trim(),
          'newPassword': newPassword,
        }),
      );
      if (response.statusCode == 200) return null;
      final error = jsonDecode(response.body);
      return error['message'] ?? 'Password reset failed. Please try again.';
    } catch (_) {
      return 'Cannot reach server. Check your connection.';
    }
  }

  Future<void> logout() async {
    _token = _myrabaHandle = _myrabaTag = _role = _fullName = null;
    notifyListeners(); // immediate UI update — navigate to login without waiting for storage
    await _storage.deleteAll();
  }

  Future<void> _saveSession(Map<String, dynamic> data) async {
    _token      = data['token'] as String?;
    _myrabaHandle = data['myrabaHandle'] as String?;
    _myrabaTag   = data['myrabaTag'] as String?;
    _role       = data['role'] as String?;
    _fullName   = data['fullName'] as String?;

    await _storage.write(key: 'jwt',      value: _token);
    await _storage.write(key: 'handle',   value: _myrabaHandle);
    await _storage.write(key: 'myrabaTag', value: _myrabaTag);
    await _storage.write(key: 'role',     value: _role);
    await _storage.write(key: 'fullName', value: _fullName);
  }
}
