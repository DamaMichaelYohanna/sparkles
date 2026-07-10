class DashboardStats {
  final double totalRevenue;
  final int pendingOrders;
  final int completedOrders;
  final int overdueOrders;
  final List<double> weeklyTrend;

  DashboardStats({
    required this.totalRevenue,
    required this.pendingOrders,
    required this.completedOrders,
    required this.overdueOrders,
    required this.weeklyTrend,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    List<double> trend = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
    if (json['weekly_trend'] is List) {
      trend = (json['weekly_trend'] as List).map((e) => double.tryParse(e.toString()) ?? 0.0).toList();
    }

    return DashboardStats(
      totalRevenue: (json['total_revenue'] ?? 0).toDouble(),
      pendingOrders: json['pending_orders'] ?? 0,
      completedOrders: json['completed_orders'] ?? 0,
      overdueOrders: json['overdue_orders'] ?? 0,
      weeklyTrend: trend,
    );
  }

  // Fallback for UI if API fails or is loading
  factory DashboardStats.empty() {
    return DashboardStats(
      totalRevenue: 0.0,
      pendingOrders: 0,
      completedOrders: 0,
      overdueOrders: 0,
      weeklyTrend: [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    );
  }
}
