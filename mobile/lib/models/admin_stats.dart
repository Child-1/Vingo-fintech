class DashboardStats {
  final int totalUsers;
  final double moneyInCirculation;
  final int activeThriftPlans;
  final double todayContributions;
  final double pendingPayouts;

  DashboardStats({
    required this.totalUsers,
    required this.moneyInCirculation,
    required this.activeThriftPlans,
    required this.todayContributions,
    required this.pendingPayouts,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      totalUsers: json['totalUsers'] ?? 0,
      moneyInCirculation: (json['moneyInCirculation'] as num).toDouble(),
      activeThriftPlans: json['activeThriftPlans'] ?? 0,
      todayContributions: (json['todayContributions'] as num).toDouble(),
      pendingPayouts: (json['pendingPayouts'] as num).toDouble(),
    );
  }
}

class AdminTransaction {
  final String senderHandle;
  final String type;
  final double amount;
  final String status;
  final String createdAt;

  AdminTransaction({
    required this.senderHandle,
    required this.type,
    required this.amount,
    required this.status,
    required this.createdAt,
  });

  factory AdminTransaction.fromJson(Map<String, dynamic> json) {
    return AdminTransaction(
      senderHandle: json['senderHandle'] ?? 'Unknown',
      type: json['type'] ?? 'TRANSFER',
      amount: (json['amount'] as num).toDouble(),
      status: json['status'] ?? 'PENDING',
      createdAt: json['createdAt'] ?? '',
    );
  }
}
