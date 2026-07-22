import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/providers.dart';
import '../../../core/models/order_model.dart';

enum FinancePeriod {
  today,
  thisWeek,
  thisMonth,
  allTime,
}

final financePeriodFilterProvider = StateProvider<FinancePeriod>((ref) => FinancePeriod.allTime);

class FinanceStats {
  final double totalRevenue;
  final double averageOrderValue;
  final int totalOrders;
  final Map<String, double> revenueByStatus;
  final List<double> weeklyTrend; // Last 7 days
  final Map<String, double> topCustomers;
  final String officeName;
  final String periodLabel;

  FinanceStats({
    required this.totalRevenue,
    required this.averageOrderValue,
    required this.totalOrders,
    required this.revenueByStatus,
    required this.weeklyTrend,
    required this.topCustomers,
    required this.periodLabel,
    this.officeName = 'My Laundry Co.',
  });
}

final financeStatsProvider = FutureProvider<FinanceStats>((ref) async {
  final filter = ref.watch(financePeriodFilterProvider);
  final syncRepo = ref.watch(syncRepositoryProvider);
  final allOrders = await syncRepo.getOrders();

  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);

  String label = 'All Time';
  final filteredOrders = allOrders.where((order) {
    final orderDate = DateTime(order.createdAt.year, order.createdAt.month, order.createdAt.day);
    switch (filter) {
      case FinancePeriod.today:
        label = 'Today';
        return orderDate.isAtSameMomentAs(todayStart);
      case FinancePeriod.thisWeek:
        label = 'Last 7 Days';
        final startOfWeek = todayStart.subtract(const Duration(days: 7));
        return orderDate.isAfter(startOfWeek);
      case FinancePeriod.thisMonth:
        label = 'Last 30 Days';
        final startOfMonth = todayStart.subtract(const Duration(days: 30));
        return orderDate.isAfter(startOfMonth);
      case FinancePeriod.allTime:
      default:
        label = 'All Time';
        return true;
    }
  }).toList();

  double totalRev = 0.0;
  Map<String, double> revByStatus = {
    'Pending': 0.0,
    'Completed': 0.0,
    'Overdue': 0.0,
  };
  
  Map<String, double> customerRev = {};
  List<double> weekly = List.filled(7, 0.0);
  
  for (final order in filteredOrders) {
    totalRev += order.totalPrice;
    
    // Status
    if (revByStatus.containsKey(order.status)) {
      revByStatus[order.status] = revByStatus[order.status]! + order.totalPrice;
    } else {
      revByStatus[order.status] = order.totalPrice;
    }
    
    // Customers
    customerRev[order.customerName] = (customerRev[order.customerName] ?? 0) + order.totalPrice;
  }

  // Calculate weekly trend ending today (always uses allOrders for continuous 7-day trend display)
  for (final order in allOrders) {
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
    averageOrderValue: filteredOrders.isEmpty ? 0 : totalRev / filteredOrders.length,
    totalOrders: filteredOrders.length,
    revenueByStatus: revByStatus,
    weeklyTrend: weekly,
    topCustomers: top5Customers,
    officeName: officeName,
    periodLabel: label,
  );
});
