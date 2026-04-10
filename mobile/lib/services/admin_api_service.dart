import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/admin_stats.dart';

/// Lightweight wrapper around the admin dashboard endpoints.
/// Requires an authenticated JWT token from AuthService.
class AdminApiService {
  final String token;
  AdminApiService(this.token);

  static String get _base => '${AppConfig.baseUrl}/api/admin';

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  Future<DashboardStats> fetchStats() async {
    final response = await http
        .get(Uri.parse('$_base/dashboard/stats'), headers: _headers)
        .timeout(AppConfig.requestTimeout);

    if (response.statusCode == 200) {
      return DashboardStats.fromJson(json.decode(response.body));
    }
    throw Exception('Failed to load dashboard stats (${response.statusCode})');
  }

  Future<List<AdminTransaction>> fetchRecentTransactions({int page = 0, int size = 10}) async {
    final response = await http
        .get(Uri.parse('$_base/transactions?page=$page&size=$size'), headers: _headers)
        .timeout(AppConfig.requestTimeout);

    if (response.statusCode == 200) {
      final body = json.decode(response.body) as Map<String, dynamic>;
      final txList = body['transactions'] as List? ?? [];
      return txList.map((data) => AdminTransaction.fromJson(data as Map<String, dynamic>)).toList();
    }
    throw Exception('Failed to load transactions (${response.statusCode})');
  }
}
