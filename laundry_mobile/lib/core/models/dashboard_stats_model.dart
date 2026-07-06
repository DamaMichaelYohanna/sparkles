class DashboardStats {
  final double totalRevenue;
  final int pendingOrders;
  final int completedOrders;
  final int overdueOrders;

  DashboardStats({
    required this.totalRevenue,
    required this.pendingOrders,
    required this.completedOrders,
    required this.overdueOrders,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      totalRevenue: (json['total_revenue'] ?? 0).toDouble(),
      pendingOrders: json['pending_orders'] ?? 0,
      completedOrders: json['completed_orders'] ?? 0,
      overdueOrders: json['overdue_orders'] ?? 0,
    );
  }

  // Fallback for UI if API fails or is loading
  factory DashboardStats.empty() {
    return DashboardStats(
      totalRevenue: 0.0,
      pendingOrders: 0,
      completedOrders: 0,
      overdueOrders: 0,
    );
  }
}
