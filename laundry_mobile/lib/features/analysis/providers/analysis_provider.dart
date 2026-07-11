import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/local_db/database_helper.dart';
import '../../../core/models/order_model.dart';

class AnalysisStats {
  final double totalSales;
  final double totalCollected;
  final double outstanding;
  final double collectionRate;
  final List<double> weeklyTrend;
  final int totalOrdersCount;

  // Operational Counts
  final int pendingOrdersCount;
  final int completedOrdersCount;
  final int overdueOrdersCount;

  // Periodic Order Aggregates
  final int weeklyOrdersCount;
  final double weeklyOrdersValue;
  final int monthlyOrdersCount;
  final double monthlyOrdersValue;
  final int yearlyOrdersCount;
  final double yearlyOrdersValue;

  // Growth & projections
  final double wowGrowth;
  final double projectedMonthlyRevenue;
  final List<String> businessInsights;

  AnalysisStats({
    required this.totalSales,
    required this.totalCollected,
    required this.outstanding,
    required this.collectionRate,
    required this.weeklyTrend,
    required this.totalOrdersCount,
    required this.pendingOrdersCount,
    required this.completedOrdersCount,
    required this.overdueOrdersCount,
    required this.weeklyOrdersCount,
    required this.weeklyOrdersValue,
    required this.monthlyOrdersCount,
    required this.monthlyOrdersValue,
    required this.yearlyOrdersCount,
    required this.yearlyOrdersValue,
    required this.wowGrowth,
    required this.projectedMonthlyRevenue,
    required this.businessInsights,
  });
}

// Primary raw data provider
final rawAnalysisOrdersProvider = FutureProvider.autoDispose<List<OrderModel>>((ref) async {
  final db = await DatabaseHelper.instance.database;
  final results = await db.query('orders', where: 'is_deleted = ?', whereArgs: [0]);
  return results.map((e) => OrderModel.fromDb(e)).toList();
});

// Aggregated stats provider
final analysisStatsProvider = Provider.autoDispose<AsyncValue<AnalysisStats>>((ref) {
  final ordersAsync = ref.watch(rawAnalysisOrdersProvider);

  return ordersAsync.when(
    loading: () => const AsyncValue.loading(),
    error: (err, stack) => AsyncValue.error(err, stack),
    data: (orders) {
      double totalSales = 0.0;
      double totalCollected = 0.0;
      int pending = 0;
      int completed = 0;
      int overdue = 0;

      for (var order in orders) {
        totalSales += order.totalPrice;
        totalCollected += order.amountPaid;

        if (order.status == 'Pending') {
          pending++;
        } else if (order.status == 'Completed') {
          completed++;
        } else if (order.status == 'Overdue') {
          overdue++;
        }
      }

      double outstanding = totalSales - totalCollected;
      double collectionRate = totalSales > 0 ? (totalCollected / totalSales) * 100 : 0.0;

      // Weekly revenue trend (Monday to Sunday)
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

      // ----------------------------------------------------
      // Periodic Order Aggregates (Weekly, Monthly, Yearly)
      // ----------------------------------------------------
      int weeklyOrdersCount = 0;
      double weeklyOrdersValue = 0.0;
      int monthlyOrdersCount = 0;
      double monthlyOrdersValue = 0.0;
      int yearlyOrdersCount = 0;
      double yearlyOrdersValue = 0.0;

      final startOfMonth = DateTime(now.year, now.month, 1);
      final startOfYear = DateTime(now.year, 1, 1);

      for (var order in orders) {
        // This Week
        if (order.createdAt.isAfter(startOfWeek.subtract(const Duration(seconds: 1))) && order.createdAt.isBefore(now)) {
          weeklyOrdersCount++;
          weeklyOrdersValue += order.totalPrice;
        }
        // This Month
        if (order.createdAt.isAfter(startOfMonth.subtract(const Duration(seconds: 1))) && order.createdAt.isBefore(now)) {
          monthlyOrdersCount++;
          monthlyOrdersValue += order.totalPrice;
        }
        // This Year
        if (order.createdAt.isAfter(startOfYear.subtract(const Duration(seconds: 1))) && order.createdAt.isBefore(now)) {
          yearlyOrdersCount++;
          yearlyOrdersValue += order.totalPrice;
        }
      }

      // ----------------------------------------------------
      // Week-over-Week (WoW) Growth Calculation
      // ----------------------------------------------------
      final startOfLastWeek = startOfWeek.subtract(const Duration(days: 7));
      final endOfLastWeek = startOfWeek;

      double thisWeekRevenue = 0.0;
      double lastWeekRevenue = 0.0;

      for (var order in orders) {
        if (order.createdAt.isAfter(startOfWeek) && order.createdAt.isBefore(now)) {
          thisWeekRevenue += order.totalPrice;
        } else if (order.createdAt.isAfter(startOfLastWeek) && order.createdAt.isBefore(endOfLastWeek)) {
          lastWeekRevenue += order.totalPrice;
        }
      }

      double wowGrowth = 0.0;
      if (lastWeekRevenue > 0) {
        wowGrowth = ((thisWeekRevenue - lastWeekRevenue) / lastWeekRevenue) * 100;
      } else if (thisWeekRevenue > 0) {
        wowGrowth = 100.0; // 100% growth if there was no revenue last week and we have some this week
      }

      // ----------------------------------------------------
      // Projected Monthly Revenue
      // ----------------------------------------------------
      // Calculate how many days we are into this week (min 1 day to avoid divide by zero)
      final daysIntoWeek = now.difference(startOfWeek).inDays.clamp(1, 7);
      // Average daily sales this week extrapolated to a full 30-day month
      double dailyAverageThisWeek = thisWeekRevenue / daysIntoWeek;
      double projectedMonthlyRevenue = dailyAverageThisWeek * 30;

      // ----------------------------------------------------
      // Actionable Business Insights Generation
      // ----------------------------------------------------
      List<String> insights = [];

      // 1. Outstanding and collections insights
      if (outstanding > 10000 && collectionRate < 70) {
        insights.add(
          "Uncollected balance is high (₦${outstanding.toStringAsFixed(0)}). Consider sending payment reminders to improve your Collection Rate (${collectionRate.toStringAsFixed(1)}%)."
        );
      } else if (collectionRate >= 90 && totalSales > 0) {
        insights.add(
          "Excellent collection performance! Your Collection Rate is at ${collectionRate.toStringAsFixed(1)}%."
        );
      }

      // 2. Operational health insights
      if (overdue > 0) {
        insights.add(
          "Operations Alert: There are $overdue overdue orders. Prioritize processing these to prevent delivery delays."
        );
      }

      // 3. Sales growth insights
      if (wowGrowth > 5) {
        insights.add(
          "Positive trend! Sales grew by ${wowGrowth.toStringAsFixed(1)}% compared to last week. Marketing and demand are rising."
        );
      } else if (wowGrowth < -5) {
        insights.add(
          "Sales dipped by ${(wowGrowth * -1).toStringAsFixed(1)}% WoW. Consider running a weekend discount or promotion."
        );
      }

      // Default insight if list is empty
      if (insights.isEmpty) {
        insights.add("Steady operations. Keep maintaining the current workflow!");
      }

      return AsyncValue.data(AnalysisStats(
        totalSales: totalSales,
        totalCollected: totalCollected,
        outstanding: outstanding,
        collectionRate: collectionRate,
        weeklyTrend: weeklyTrend,
        totalOrdersCount: orders.length,
        pendingOrdersCount: pending,
        completedOrdersCount: completed,
        overdueOrdersCount: overdue,
        weeklyOrdersCount: weeklyOrdersCount,
        weeklyOrdersValue: weeklyOrdersValue,
        monthlyOrdersCount: monthlyOrdersCount,
        monthlyOrdersValue: monthlyOrdersValue,
        yearlyOrdersCount: yearlyOrdersCount,
        yearlyOrdersValue: yearlyOrdersValue,
        wowGrowth: wowGrowth,
        projectedMonthlyRevenue: projectedMonthlyRevenue,
        businessInsights: insights,
      ));
    },
  );
});
