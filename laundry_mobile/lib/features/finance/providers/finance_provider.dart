import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/providers.dart';
import '../../../core/models/order_model.dart';

class FinanceStats {
  final double totalRevenue;
  final double averageOrderValue;
  final int totalOrders;
  final Map<String, double> revenueByStatus;
  final List<double> weeklyTrend; // Last 7 days
  final Map<String, double> topCustomers;
  final String officeName;

  FinanceStats({
    required this.totalRevenue,
    required this.averageOrderValue,
    required this.totalOrders,
    required this.revenueByStatus,
    required this.weeklyTrend,
    required this.topCustomers,
    this.officeName = 'My Laundry Co.',
  });
}

final financeStatsProvider = FutureProvider<FinanceStats>((ref) async {
  final syncRepo = ref.watch(syncRepositoryProvider);
  final orders = await syncRepo.getOrders();

  double totalRev = 0.0;
  Map<String, double> revByStatus = {
    'Pending': 0.0,
    'Completed': 0.0,
    'Overdue': 0.0,
  };
  
  Map<String, double> customerRev = {};
  List<double> weekly = List.filled(7, 0.0);
  
  final now = DateTime.now();
  // We want the last 7 days ending today
  final todayStart = DateTime(now.year, now.month, now.day);
  
  for (final order in orders) {
    totalRev += order.totalPrice;
    
    // Status
    if (revByStatus.containsKey(order.status)) {
      revByStatus[order.status] = revByStatus[order.status]! + order.totalPrice;
    } else {
      revByStatus[order.status] = order.totalPrice;
    }
    
    // Customers
    customerRev[order.customerName] = (customerRev[order.customerName] ?? 0) + order.totalPrice;
    
    // Weekly Trend (last 7 days, index 6 is today, index 0 is 6 days ago)
    final daysDifference = todayStart.difference(DateTime(order.createdAt.year, order.createdAt.month, order.createdAt.day)).inDays;
    if (daysDifference >= 0 && daysDifference < 7) {
      final index = 6 - daysDifference;
      weekly[index] += order.totalPrice;
    }
  }
  
  final topCustomersEntries = customerRev.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
    
  final top5Customers = Map.fromEntries(topCustomersEntries.take(5));

  final prefs = await SharedPreferences.getInstance();
  final officeName = prefs.getString('office_name') ?? 'My Laundry Co.';

  return FinanceStats(
    totalRevenue: totalRev,
    averageOrderValue: orders.isEmpty ? 0 : totalRev / orders.length,
    totalOrders: orders.length,
    revenueByStatus: revByStatus,
    weeklyTrend: weekly,
    topCustomers: top5Customers,
    officeName: officeName,
  );
});
