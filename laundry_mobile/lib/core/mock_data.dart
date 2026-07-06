class MockData {
  static final dashboardStats = {
    'totalRevenue': 12450.00,
    'pendingOrders': 14,
    'completedOrders': 42,
    'overdueOrders': 3,
  };

  static final List<Map<String, dynamic>> recentOrders = [
    {'id': 'ORD-001', 'customer': 'John Doe', 'status': 'Pending', 'total': 45.00, 'date': 'Today'},
    {'id': 'ORD-002', 'customer': 'Jane Smith', 'status': 'Completed', 'total': 120.50, 'date': 'Today'},
    {'id': 'ORD-003', 'customer': 'Mike Johnson', 'status': 'Overdue', 'total': 30.00, 'date': 'Yesterday'},
    {'id': 'ORD-004', 'customer': 'Emily Brown', 'status': 'Pending', 'total': 85.00, 'date': 'Yesterday'},
    {'id': 'ORD-005', 'customer': 'Chris Davis', 'status': 'Completed', 'total': 210.00, 'date': 'Yesterday'},
  ];

  static final List<double> weeklyRevenue = [450, 600, 300, 800, 550, 900, 1200];
}
