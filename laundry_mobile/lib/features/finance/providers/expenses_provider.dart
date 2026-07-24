import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/local_db/database_helper.dart';
import '../../../core/models/expense_model.dart';
import '../../../core/models/order_model.dart';
import '../../../core/providers.dart';
import '../../analysis/providers/analysis_provider.dart';

/// Provider containing the list of all expenses from SQLite.
final expensesListProvider = FutureProvider.autoDispose<List<ExpenseModel>>((ref) async {
  final db = await DatabaseHelper.instance.database;
  final results = await db.query(
    'expenses',
    where: 'is_deleted = ?',
    whereArgs: [0],
    orderBy: 'created_at DESC',
  );
  return results.map((e) => ExpenseModel.fromDb(e)).toList();
});

/// StateNotifier/Notifier for handling Expense CRUD operations locally.
class ExpensesNotifier extends Notifier<void> {
  @override
  void build() {}

  Future<void> addExpense(double amount, String description, String category) async {
    final db = await DatabaseHelper.instance.database;
    final expense = ExpenseModel(
      id: const Uuid().v4(),
      amount: amount,
      description: description,
      category: category,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      syncStatus: 'pending',
    );
    await db.insert('expenses', expense.toDb());
    ref.invalidate(expensesListProvider);
    // invalidate all dailySheetProvider instances
    ref.invalidate(dailySheetProvider);
  }

  Future<void> editExpense(ExpenseModel expense) async {
    final db = await DatabaseHelper.instance.database;
    final updated = expense.copyWith(
      updatedAt: DateTime.now(),
      syncStatus: 'pending',
    );
    await db.update(
      'expenses',
      updated.toDb(),
      where: 'id = ?',
      whereArgs: [updated.id],
    );
    ref.invalidate(expensesListProvider);
    ref.invalidate(dailySheetProvider);
  }

  Future<void> deleteExpense(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'expenses',
      {
        'is_deleted': 1,
        'updated_at': DateTime.now().toIso8601String(),
        'sync_status': 'pending',
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    ref.invalidate(expensesListProvider);
    ref.invalidate(dailySheetProvider);
  }
}

final expensesNotifierProvider = NotifierProvider<ExpensesNotifier, void>(() {
  return ExpensesNotifier();
});

/// Data structure for the Daily Balance Sheet.
class DailySheetData {
  final double totalIncome;
  final double totalExpenses;
  final double netBalance;
  final List<OrderModel> incomeOrders;
  final List<ExpenseModel> expenseList;

  DailySheetData({
    required this.totalIncome,
    required this.totalExpenses,
    required this.netBalance,
    required this.incomeOrders,
    required this.expenseList,
  });
}

/// Provider that calculates daily income, expenses, and net profit for any given date.
final dailySheetProvider = FutureProvider.autoDispose.family<DailySheetData, DateTime>((ref, date) async {
  final db = await DatabaseHelper.instance.database;

  // Local start and end bounds of the selected date
  final startOfDay = DateTime(date.year, date.month, date.day);
  final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

  // 1. Fetch Income (Payments collected on this day)
  final orderResults = await db.query(
    'orders',
    where: 'is_deleted = ?',
    whereArgs: [0],
  );

  final allOrders = orderResults.map((e) => OrderModel.fromDb(e)).toList();
  final incomeOrders = allOrders.where((order) {
    final localCreated = order.createdAt.toLocal();
    return localCreated.isAfter(startOfDay.subtract(const Duration(milliseconds: 1))) &&
           localCreated.isBefore(endOfDay.add(const Duration(milliseconds: 1))) &&
           order.amountPaid > 0;
  }).toList();

  final double totalIncome = incomeOrders.fold(0.0, (sum, order) => sum + order.amountPaid);

  // 2. Fetch Expenses logged on this day
  final expenseResults = await db.query(
    'expenses',
    where: 'is_deleted = ?',
    whereArgs: [0],
  );

  final allExpenses = expenseResults.map((e) => ExpenseModel.fromDb(e)).toList();
  final dayExpenses = allExpenses.where((exp) {
    final localCreated = exp.createdAt.toLocal();
    return localCreated.isAfter(startOfDay.subtract(const Duration(milliseconds: 1))) &&
           localCreated.isBefore(endOfDay.add(const Duration(milliseconds: 1)));
  }).toList();

  final double totalExpenses = dayExpenses.fold(0.0, (sum, exp) => sum + exp.amount);

  return DailySheetData(
    totalIncome: totalIncome,
    totalExpenses: totalExpenses,
    netBalance: totalIncome - totalExpenses,
    incomeOrders: incomeOrders,
    expenseList: dayExpenses,
  );
});

/// Provider that reactively filters all expenses based on the active Business Analysis filter.
final filteredExpensesProvider = Provider.autoDispose<AsyncValue<double>>((ref) {
  final expensesAsync = ref.watch(expensesListProvider);
  final filter = ref.watch(analysisFilterProvider);

  return expensesAsync.when(
    loading: () => const AsyncValue.loading(),
    error: (err, stack) => AsyncValue.error(err, stack),
    data: (allExpenses) {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);

      final filtered = allExpenses.where((exp) {
        final localDate = DateTime(exp.createdAt.toLocal().year, exp.createdAt.toLocal().month, exp.createdAt.toLocal().day);

        if (filter.dateRange == 'Today' && !localDate.isAtSameMomentAs(todayStart)) {
          return false;
        }
        if (filter.dateRange == 'This Week') {
          final startOfWeek = todayStart.subtract(Duration(days: todayStart.weekday - 1));
          if (localDate.isBefore(startOfWeek)) return false;
        }
        if (filter.dateRange == 'This Month') {
          final startOfMonth = DateTime(todayStart.year, todayStart.month, 1);
          if (localDate.isBefore(startOfMonth)) return false;
        }
        if (filter.dateRange == 'Custom' && filter.customDateRange != null) {
          final start = DateTime(filter.customDateRange!.start.year, filter.customDateRange!.start.month, filter.customDateRange!.start.day);
          final end = DateTime(filter.customDateRange!.end.year, filter.customDateRange!.end.month, filter.customDateRange!.end.day, 23, 59, 59);
          if (localDate.isBefore(start) || localDate.isAfter(end)) return false;
        }

        return true;
      }).toList();

      return AsyncValue.data(filtered.fold(0.0, (sum, exp) => sum + exp.amount));
    },
  );
});
