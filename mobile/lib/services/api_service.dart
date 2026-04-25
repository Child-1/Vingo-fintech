import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../config/app_config.dart';

class ApiService {
  static String get base => AppConfig.baseUrl;
  static const _uuid = Uuid();

  final String token;
  ApiService(this.token);

  Map<String, String> get _h => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  /// Headers with an idempotency key — use for any money-moving POST
  Map<String, String> _idempotentHeaders([String? key]) => {
    ..._h,
    'Idempotency-Key': key ?? _uuid.v4(),
  };

  // ─── Wallet ───────────────────────────────────────────────────

  Future<Map<String, dynamic>> getWallet(String myrabaHandle) =>
      _get('/wallets/$myrabaHandle');

  Future<Map<String, dynamic>> getHistory() =>
      _get('/wallets/history');

  Future<Map<String, dynamic>> getMonthlyReview({int months = 12}) =>
      _get('/wallets/monthly-review?months=$months');

  Future<Map<String, dynamic>> getSpendingBreakdown({int months = 3}) =>
      _get('/wallets/spending-breakdown?months=$months');

  Future<Map<String, dynamic>> transfer(String recipientMyrabaHandle, String amount, {String? idempotencyKey}) =>
      _postIdempotent('/wallets/transfer',
          {'receiverVingHandle': recipientMyrabaHandle, 'amount': amount},
          idempotencyKey);

  Future<Map<String, dynamic>> transferByAccount(String accountNumber, String amount, {String? idempotencyKey}) =>
      _postIdempotent('/wallets/transfer/account',
          {'accountNumber': accountNumber, 'amount': amount},
          idempotencyKey);

  Future<Map<String, dynamic>> transferByCustomId(String customId, String amount, {String? idempotencyKey}) =>
      _postIdempotent('/wallets/transfer/custom-id',
          {'customAccountId': customId, 'amount': amount},
          idempotencyKey);

  Future<Map<String, dynamic>> fundWallet(String myrabaHandle, String amount) =>
      _post('/wallets/fund', {'myrabaHandle': myrabaHandle, 'amount': amount});

  // ─── User Profile ─────────────────────────────────────────────

  Future<Map<String, dynamic>> getMyProfile() => _get('/api/users/me');

  Future<Map<String, dynamic>> getUserByHandle(String handle) =>
      _get('/api/users/handle/$handle');

  Future<Map<String, dynamic>> getMyQr() => _get('/api/users/me/qr');

  Future<Map<String, dynamic>> updateMyProfile({String? fullName, String? phone, String? email, String? address, String? customAccountId, String? gender}) =>
      _putStrict('/api/users/me', {
        if (fullName != null) 'fullName': fullName,
        if (phone != null) 'phone': phone,
        if (email != null) 'email': email,
        if (address != null) 'address': address,
        if (customAccountId != null) 'customAccountId': customAccountId,
        if (gender != null) 'gender': gender,
      });

  Future<Map<String, dynamic>> lookupAccountByNumber(String accountNumber) =>
      _get('/wallets/lookup/account/$accountNumber');

  Future<Map<String, dynamic>> lookupRecipientByHandle(String handle) =>
      _get('/wallets/$handle');

  Future<Map<String, dynamic>> uploadAvatar(File imageFile) async {
    final uri = Uri.parse('$base/api/users/me/avatar');
    final req = http.MultipartRequest('POST', uri)
      ..headers.addAll({'Authorization': 'Bearer $token'})
      ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    return _parseStrict(res);
  }

  Future<Map<String, dynamic>> changePassword(String currentPassword, String newPassword) =>
      _post('/api/users/me/change-password', {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      });

  // ─── Thrift ───────────────────────────────────────────────────

  Future<Map<String, dynamic>> getThriftCategories() =>
      _get('/api/thrifts/categories');

  Future<Map<String, dynamic>> getMyThrifts() => _get('/api/thrifts/me');

  Future<Map<String, dynamic>> joinThrift(int categoryId) =>
      _post('/api/thrifts/categories/$categoryId/join', {});

  Future<Map<String, dynamic>> contribute(int memberId) =>
      _post('/api/thrifts/me/contribute/$memberId', {});

  // Private thrift
  Future<Map<String, dynamic>> getMyPrivateThrifts() =>
      _get('/api/private-thrifts/me');

  Future<Map<String, dynamic>> joinPrivateThrift(String inviteCode) =>
      _post('/api/private-thrifts/join/$inviteCode', {});

  Future<Map<String, dynamic>> acceptThriftRules(int thriftId) =>
      _post('/api/private-thrifts/$thriftId/accept-rules', {});

  Future<Map<String, dynamic>> createPrivateThrift({
    required String name,
    String? description,
    required String contributionAmount,
    required String frequency,
    required int totalCycles,
    String positionAssignment = 'RAFFLE',
    String? creatorRules,
  }) => _postStrict('/api/private-thrifts', {
    'name': name,
    if (description != null) 'description': description,
    'contributionAmount': num.tryParse(contributionAmount) ?? 0,
    'frequency': frequency,
    'totalCycles': totalCycles,
    'positionAssignment': positionAssignment,
    if (creatorRules != null) 'creatorRules': creatorRules,
  });

  // ─── Gifts ────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getGiftCategories() =>
      _get('/api/gifts/categories');

  Future<Map<String, dynamic>> getGiftItems(int categoryId) =>
      _get('/api/gifts/categories/$categoryId/items');

  Future<Map<String, dynamic>> getGiftBalance() => _get('/api/gifts/balance');

  Future<Map<String, dynamic>> sendGift({
    required String recipientMyrabaHandle,
    required int giftItemId,
    String? note,
    bool anonymous = false,
  }) => _postStrict('/api/gifts/send', {
    'recipientMyrabaHandle': recipientMyrabaHandle,
    'giftItemId': giftItemId,
    'note': note,
    'anonymous': anonymous,
  });

  Future<Map<String, dynamic>> getReceivedGifts() => _get('/api/gifts/received');
  Future<Map<String, dynamic>> getSentGifts() => _get('/api/gifts/sent');

  Future<Map<String, dynamic>> convertGiftBalance(String amount) =>
      _post('/api/gifts/balance/convert', {'amount': double.tryParse(amount) ?? 0.0});

  // ─── Bills ────────────────────────────────────────────────────

  Future<Map<String, dynamic>> buyAirtime(String phone, String amount, String network) =>
      _post('/api/bills/airtime', {'phone': phone, 'amount': amount, 'network': network});

  Future<Map<String, dynamic>> buyData(String phone, String network, String planCode) =>
      _post('/api/bills/data', {'phone': phone, 'network': network, 'planCode': planCode});

  Future<Map<String, dynamic>> payElectricity({
    required String meterNumber, required String disco,
    required String meterType,  required String amount, required String phone,
  }) => _post('/api/bills/electricity', {
    'meterNumber': meterNumber, 'disco': disco,
    'meterType': meterType, 'amount': amount, 'phone': phone,
  });

  Future<Map<String, dynamic>> payCable({
    required String smartCardNumber, required String provider,
    required String planCode, required String phone,
  }) => _post('/api/bills/cable', {
    'smartCardNumber': smartCardNumber, 'provider': provider,
    'planCode': planCode, 'phone': phone,
  });

  Future<Map<String, dynamic>> fundBetting({
    required String bettingUserId, required String provider,
    required String amount, required String phone,
  }) => _post('/api/bills/betting', {
    'bettingUserId': bettingUserId, 'provider': provider,
    'amount': amount, 'phone': phone,
  });

  Future<Map<String, dynamic>> paySchoolFees({
    required String schoolName,
    required String studentId,
    required String studentName,
    required String paymentType,
    required String phone,
    required String amount,
  }) => _postStrict('/api/bills/school-fees', {
    'schoolName': schoolName,
    'studentId': studentId,
    'studentName': studentName,
    'paymentType': paymentType,
    'phone': phone,
    'amount': num.tryParse(amount) ?? 0,
  });

  Future<Map<String, dynamic>> payEducation({
    required String examBody,      // WAEC, NECO, JAMB
    required String profileCode,   // JAMB profile code or phone for WAEC/NECO
    required String phone,
    int quantity = 1,
    required String amount,
  }) => _postStrict('/api/bills/education', {
    'examBody': examBody,
    'profileCode': profileCode,
    'phone': phone,
    'quantity': quantity,
    'amount': num.tryParse(amount) ?? 0,
  });

  Future<Map<String, dynamic>> getBillHistory({String? category}) =>
      _get('/api/bills/history${category != null ? '?category=$category' : ''}');

  // ─── KYC ──────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getKycStatus() => _get('/api/kyc/status');

  Future<Map<String, dynamic>> submitBvn(String bvn) =>
      _post('/api/kyc/verify/bvn', {'bvn': bvn});

  Future<Map<String, dynamic>> submitNin(String nin) =>
      _post('/api/kyc/verify/nin', {'nin': nin});

  // ─── Points ───────────────────────────────────────────────────

  Future<Map<String, dynamic>> getMyPoints() => _get('/api/points');
  Future<Map<String, dynamic>> getPointHistory() => _get('/api/points/history');
  Future<Map<String, dynamic>> getWrapped(int year) => _get('/api/wrapped/$year');

  // ─── Broadcasts (user-facing) ──────────────────────────────────

  Future<Map<String, dynamic>> getMyBroadcasts() => _get('/api/broadcasts');

  // ─── Admin: Dashboard ─────────────────────────────────────────

  Future<Map<String, dynamic>> adminGetStats() => _get('/api/admin/dashboard/stats');

  // ─── Admin: Users ─────────────────────────────────────────────

  Future<Map<String, dynamic>> adminListUsers({
    int page = 0, int size = 20,
    String? search, String? status, String? kycStatus, String? role,
  }) {
    final params = <String, String>{'page': '$page', 'size': '$size'};
    if (search != null) params['search'] = search;
    if (status != null) params['status'] = status;
    if (kycStatus != null) params['kycStatus'] = kycStatus;
    if (role != null) params['role'] = role;
    return _getWithParams('/api/admin/users', params);
  }

  Future<Map<String, dynamic>> adminGetUser(int id) => _get('/api/admin/users/$id');

  Future<Map<String, dynamic>> adminUpdateRole(int id, String role) =>
      _put('/api/admin/users/$id/role', {'role': role});

  Future<Map<String, dynamic>> adminUpdateKyc(int id, String status) =>
      _put('/api/admin/users/$id/kyc', {'status': status});

  Future<Map<String, dynamic>> adminFreezeAccount(int id, String reason) =>
      _post('/api/admin/users/$id/freeze', {'reason': reason});

  Future<Map<String, dynamic>> adminSuspendAccount(int id, String reason) =>
      _post('/api/admin/users/$id/suspend', {'reason': reason});

  Future<Map<String, dynamic>> adminActivateAccount(int id, String reason) =>
      _post('/api/admin/users/$id/activate', {'reason': reason});

  Future<Map<String, dynamic>> adminGetUserStats(int id, {String? from, String? to}) {
    final params = <String, String>{};
    if (from != null) params['from'] = from;
    if (to != null) params['to'] = to;
    return _getWithParams('/api/admin/users/$id/stats', params);
  }

  Future<Map<String, dynamic>> adminGetUserStatsOverview() =>
      _get('/api/admin/users/stats/overview');

  // ─── Admin: Balance Adjustment ────────────────────────────────

  Future<Map<String, dynamic>> adminAdjustBalance({
    required String myrabaHandle, required String amount, required String reason,
  }) => _post('/api/admin/balance/adjust', {
    'myrabaHandle': myrabaHandle, 'amount': amount, 'reason': reason,
  });

  // ─── Admin: Transactions ──────────────────────────────────────

  Future<Map<String, dynamic>> adminListTransactions({
    int page = 0, int size = 20,
    String? type, String? status,
    String? from, String? to,
    String? minAmount, String? maxAmount,
  }) {
    final params = <String, String>{'page': '$page', 'size': '$size'};
    if (type != null) params['type'] = type;
    if (status != null) params['status'] = status;
    if (from != null) params['from'] = from;
    if (to != null) params['to'] = to;
    if (minAmount != null) params['minAmount'] = minAmount;
    if (maxAmount != null) params['maxAmount'] = maxAmount;
    return _getWithParams('/api/admin/transactions', params);
  }

  Future<Map<String, dynamic>> adminGetTransaction(int id) =>
      _get('/api/admin/transactions/$id');

  Future<Map<String, dynamic>> adminReverseTransaction(int id, String reason) =>
      _post('/api/admin/transactions/$id/reverse', {'reason': reason});

  Future<Map<String, dynamic>> adminGetTransactionSummary() =>
      _get('/api/admin/transactions/summary');

  Future<Map<String, dynamic>> adminGetUserTransactions(String myrabaHandle) =>
      _get('/api/admin/transactions/user/$myrabaHandle');

  // ─── Admin: Reports ───────────────────────────────────────────

  Future<Map<String, dynamic>> adminGetDailyReport({String? date}) {
    final params = date != null ? {'date': date} : <String, String>{};
    return _getWithParams('/api/admin/reports/daily', params);
  }

  Future<Map<String, dynamic>> adminGetMonthlyReport({int? year, int? month}) {
    final params = <String, String>{};
    if (year != null) params['year'] = '$year';
    if (month != null) params['month'] = '$month';
    return _getWithParams('/api/admin/reports/monthly', params);
  }

  Future<Map<String, dynamic>> adminGetDailyBreakdown({int days = 30}) =>
      _getWithParams('/api/admin/reports/daily-breakdown', {'days': '$days'});

  Future<Map<String, dynamic>> adminGetPlatformTotals() =>
      _get('/api/admin/reports/totals');

  // ─── Admin: Audit Log ─────────────────────────────────────────

  Future<Map<String, dynamic>> adminGetAuditLogs({
    int page = 0, int size = 50,
    String? adminHandle, String? action,
    String? targetType, String? targetId,
  }) {
    final params = <String, String>{'page': '$page', 'size': '$size'};
    if (adminHandle != null) params['adminHandle'] = adminHandle;
    if (action != null) params['action'] = action;
    if (targetType != null) params['targetType'] = targetType;
    if (targetId != null) params['targetId'] = targetId;
    return _getWithParams('/api/admin/audit', params);
  }

  // ─── Admin: Broadcasts ────────────────────────────────────────

  Future<Map<String, dynamic>> adminListBroadcasts() =>
      _get('/api/admin/broadcasts');

  Future<Map<String, dynamic>> adminSendBroadcast({
    required String title, required String body,
    String type = 'INFO', String audience = 'ALL',
    String? targetMyrabaHandle,
  }) => _post('/api/admin/broadcasts', {
    'title': title, 'body': body, 'type': type,
    'audience': audience,
    if (targetMyrabaHandle != null) 'targetMyrabaHandle': targetMyrabaHandle,
  });

  Future<Map<String, dynamic>> adminDeactivateBroadcast(int id) =>
      _delete('/api/admin/broadcasts/$id');

  // ─── HTTP helpers ─────────────────────────────────────────────

  Future<Map<String, dynamic>> _get(String path) async {
    final res = await http.get(Uri.parse('$base$path'), headers: _h);
    return _parse(res);
  }

  Future<Map<String, dynamic>> _getWithParams(String path, Map<String, String> params) async {
    final uri = Uri.parse('$base$path').replace(queryParameters: params.isEmpty ? null : params);
    final res = await http.get(uri, headers: _h);
    return _parse(res);
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final res = await http.post(Uri.parse('$base$path'),
        headers: _h, body: jsonEncode(body));
    return _parse(res);
  }

  /// POST with auto-generated (or caller-supplied) idempotency key
  Future<Map<String, dynamic>> _postIdempotent(
      String path, Map<String, dynamic> body, String? key) async {
    final res = await http.post(Uri.parse('$base$path'),
        headers: _idempotentHeaders(key), body: jsonEncode(body));
    return _parse(res);
  }

  Future<Map<String, dynamic>> _put(String path, Map<String, dynamic> body) async {
    final res = await http.put(Uri.parse('$base$path'),
        headers: _h, body: jsonEncode(body));
    return _parse(res);
  }

  Future<Map<String, dynamic>> _delete(String path) async {
    final res = await http.delete(Uri.parse('$base$path'), headers: _h);
    return _parse(res);
  }

  Map<String, dynamic> _parse(http.Response res) {
    final decoded = jsonDecode(res.body);
    if (decoded is Map<String, dynamic>) return decoded;
    return {'data': decoded};
  }

  /// Like _parse but throws an Exception on 4xx / 5xx so callers can show the error.
  Map<String, dynamic> _parseStrict(http.Response res) {
    final data = _parse(res);
    if (res.statusCode >= 400) {
      throw Exception(
        data['message'] as String? ??
        data['error'] as String? ??
        'Request failed (${res.statusCode})',
      );
    }
    return data;
  }

  Future<Map<String, dynamic>> _postStrict(String path, Map<String, dynamic> body) async {
    final res = await http.post(Uri.parse('$base$path'),
        headers: _h, body: jsonEncode(body));
    return _parseStrict(res);
  }

  Future<Map<String, dynamic>> _putStrict(String path, Map<String, dynamic> body) async {
    final res = await http.put(Uri.parse('$base$path'),
        headers: _h, body: jsonEncode(body));
    return _parseStrict(res);
  }

  // ── Fixed Deposits ──────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getFixedDeposits() => _get('/api/fixed-deposits');
  Future<Map<String, dynamic>> createFixedDeposit(double amount, int termDays) =>
      _postStrict('/api/fixed-deposits', {'amount': amount, 'termDays': termDays});
  Future<Map<String, dynamic>> withdrawDeposit(int depositId) =>
      _postStrict('/api/fixed-deposits/$depositId/withdraw', {});

  // ── Support Chat ────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getSupportMessages() => _get('/api/support/messages');
  Future<Map<String, dynamic>> sendSupportMessage(String content) =>
      _post('/api/support/messages', {'content': content});
  Future<Map<String, dynamic>> getSupportUnreadCount() => _get('/api/support/unread-count');

  // ── Community Goals ─────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> createGoal(Map<String, dynamic> body) =>
      _post('/api/goals', body);
  Future<Map<String, dynamic>> getMyGoals() => _get('/api/goals/my');
  Future<Map<String, dynamic>> getGoalsIBack() => _get('/api/goals/backing');
  Future<Map<String, dynamic>> getGoalByCode(String code) =>
      _get('/api/goals/${code.toUpperCase()}');
  Future<Map<String, dynamic>> contributeToGoal(String code, double amount, {String? note}) =>
      _post('/api/goals/$code/contribute', {'amount': amount, if (note != null) 'note': note});
  Future<Map<String, dynamic>> withdrawGoal(int goalId) =>
      _post('/api/goals/$goalId/withdraw', {});
  Future<Map<String, dynamic>> cancelGoal(int goalId) =>
      _delete('/api/goals/$goalId');

  Future<Map<String, dynamic>> getMyReferrals() => _get('/api/referrals/my');

  Future<Map<String, dynamic>> getDisputes() => _get('/api/disputes/my');
  Future<Map<String, dynamic>> fileDispute(Map<String, dynamic> body) =>
      _post('/api/disputes', body);
  Future<Map<String, dynamic>> getSpendingByCategory({int months = 3}) =>
      _get('/api/bills/history');
}
