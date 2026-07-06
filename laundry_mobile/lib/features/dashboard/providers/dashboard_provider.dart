import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/dashboard_stats_model.dart';
import '../../core/models/order_model.dart';
import '../../core/providers.dart';

final dashboardStatsProvider = FutureProvider.autoDispose<DashboardStats>((ref) async {
  // For offline first, we could also cache this, but let's just fetch for now
  // or return default stats on failure.
  final api = ref.watch(apiServiceProvider);
  try {
    final response = await api.dio.get('/dashboard/operations/');
    return DashboardStats.fromJson(response.data);
  } catch (e) {
    return DashboardStats(totalRevenue: 0, pendingOrders: 0, completedOrders: 0, overdueOrders: 0);
  }
});

final recentOrdersProvider = FutureProvider.autoDispose<List<OrderModel>>((ref) async {
  final syncRepo = ref.watch(syncRepositoryProvider);
  final orders = await syncRepo.getOrders();
  // Sort and limit locally
  orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return orders.take(5).toList();
});
