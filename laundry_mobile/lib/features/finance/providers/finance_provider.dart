import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/local_db/database_helper.dart';
import '../../../core/models/order_model.dart';

class FinanceStats {
  final double totalSales;
  final double totalCollected;
  final double outstanding;
  final double collectionRate;
  final List<double> weeklyTrend;
  final int totalOrdersCount;

  FinanceStats({
    required this.totalSales,
    required this.totalCollected,
    required this.outstanding,
    required this.collectionRate,
    required this.weeklyTrend,
    required this.totalOrdersCount,
  });
}

// Primary raw data provider
final rawFinanceOrdersProvider = FutureProvider.autoDispose<List<OrderModel>>((ref) async {
  final db = await DatabaseHelper.instance.database;
  final results = await db.query('orders', where: 'is_deleted = ?', whereArgs: [0]);
  return results.map((e) => OrderModel.fromDb(e)).toList();
});

// Aggregated stats provider
final financeStatsProvider = Provider.autoDispose<AsyncValue<FinanceStats>>((ref) {
  final ordersAsync = ref.watch(rawFinanceOrdersProvider);
  
  return ordersAsync.when(
    loading: () => const AsyncValue.loading(),
    error: (err, stack) => AsyncValue.error(err, stack),
    data: (orders) {
      double totalSales = 0.0;
      double totalCollected = 0.0;

      for (var order in orders) {
        totalSales += order.totalPrice;
        totalCollected += order.amountPaid;
      }

      double outstanding = totalSales - totalCollected;
      double collectionRate = totalSales > 0 ? (totalCollected / totalSales) * 100 : 0.0;

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

      return AsyncValue.data(FinanceStats(
        totalSales: totalSales,
        totalCollected: totalCollected,
        outstanding: outstanding,
        collectionRate: collectionRate,
        weeklyTrend: weeklyTrend,
        totalOrdersCount: orders.length,
      ));
    },
  );
});
