import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laundry_mobile/core/models/dashboard_stats_model.dart';
import 'package:laundry_mobile/core/models/order_model.dart';
import 'package:laundry_mobile/core/providers.dart';
import 'package:laundry_mobile/core/local_db/database_helper.dart';

/// Performs a full sync first, then reads the DB.
/// This keeps the FutureProvider in the [loading] state (skeleton UI)
/// until we have fresh data — never shows stale/wrong numbers.
final dashboardStatsProvider = FutureProvider.autoDispose<DashboardStats>((ref) async {
  final syncRepo = ref.watch(syncRepositoryProvider);

  // Await the sync so we only read the DB once fresh data has landed.
  await syncRepo.awaitSync();

  final db = await DatabaseHelper.instance.database;
  final results = await db.query('orders', where: 'is_deleted = ?', whereArgs: [0]);
  final orders = results.map((e) => OrderModel.fromDb(e)).toList();

  double totalRevenue = 0.0;
  int pending = 0;
  int completed = 0;
  int overdue = 0;

  for (var order in orders) {
    totalRevenue += order.amountPaid;
    if (order.status == 'Pending') {
      pending++;
    } else if (order.status == 'Completed') {
      completed++;
    } else if (order.status == 'Overdue') {
      overdue++;
    }
  }

  // Calculate weekly trend (Monday to Sunday)
  List<double> weeklyTrend = List.generate(7, (_) => 0.0);
  final now = DateTime.now();
  final monday = now.subtract(Duration(days: now.weekday - 1));
  final startOfWeek = DateTime(monday.year, monday.month, monday.day);
  final endOfWeek = startOfWeek.add(const Duration(days: 7));

  for (var order in orders) {
    if (order.createdAt.isAfter(startOfWeek) && order.createdAt.isBefore(endOfWeek)) {
      int weekday = order.createdAt.weekday; // 1 = Mon, 7 = Sun
      weeklyTrend[weekday - 1] += order.totalPrice;
    }
  }

  return DashboardStats(
    totalRevenue: totalRevenue,
    pendingOrders: pending,
    completedOrders: completed,
    overdueOrders: overdue,
    weeklyTrend: weeklyTrend,
  );
});

final recentOrdersProvider = FutureProvider.autoDispose<List<OrderModel>>((ref) async {
  ref.watch(lastSyncTimestampProvider);
  final syncRepo = ref.watch(syncRepositoryProvider);
  final orders = await syncRepo.getOrders();
  // Sort and limit locally
  orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return orders.take(5).toList();
});
