import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laundry_mobile/core/models/order_model.dart';
import 'package:laundry_mobile/core/providers.dart';

final ordersListProvider = FutureProvider.autoDispose<List<OrderModel>>((ref) async {
  final syncRepo = ref.watch(syncRepositoryProvider);
  return await syncRepo.getOrders();
});

class OrdersFilterState {
  final String status;
  final String paymentStatus;
  final String dateRange; // 'All Time', 'Today', 'This Week', 'This Month', 'Custom'
  final DateTimeRange? customDateRange;

  OrdersFilterState({
    this.status = 'All',
    this.paymentStatus = 'All',
    this.dateRange = 'All Time',
    this.customDateRange,
  });

  OrdersFilterState copyWith({
    String? status,
    String? paymentStatus,
    String? dateRange,
    DateTimeRange? customDateRange,
  }) {
    return OrdersFilterState(
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      dateRange: dateRange ?? this.dateRange,
      customDateRange: customDateRange ?? this.customDateRange,
    );
  }
}

class OrdersFilterNotifier extends Notifier<OrdersFilterState> {
  @override
  OrdersFilterState build() => OrdersFilterState();

  void setStatus(String value) => state = state.copyWith(status: value);
  void setPaymentStatus(String value) => state = state.copyWith(paymentStatus: value);
  void setDateRange(String value) {
    if (value != 'Custom') {
      state = state.copyWith(dateRange: value, customDateRange: null);
    } else {
      state = state.copyWith(dateRange: value);
    }
  }
  void setCustomDateRange(DateTimeRange? range) {
    state = state.copyWith(dateRange: 'Custom', customDateRange: range);
  }
  void reset() {
    state = OrdersFilterState();
  }
}

final ordersFilterProvider = NotifierProvider<OrdersFilterNotifier, OrdersFilterState>(() {
  return OrdersFilterNotifier();
});

final filteredOrdersListProvider = Provider.autoDispose<AsyncValue<List<OrderModel>>>((ref) {
  final ordersAsync = ref.watch(ordersListProvider);
  final filter = ref.watch(ordersFilterProvider);

  return ordersAsync.when(
    loading: () => const AsyncValue.loading(),
    error: (err, stack) => AsyncValue.error(err, stack),
    data: (orders) {
      final now = DateTime.now();
      List<OrderModel> filtered = orders;

      // 1. Order Status Filter
      if (filter.status != 'All') {
        filtered = filtered.where((o) => o.status == filter.status).toList();
      }

      // 2. Payment Status Filter
      filtered = filtered.where((o) {
        final balance = o.totalPrice - o.amountPaid;
        switch (filter.paymentStatus) {
          case 'Fully Paid':
            return balance <= 0 && o.totalPrice > 0;
          case 'Partially Paid':
            return o.amountPaid > 0 && balance > 0;
          case 'Unpaid':
            return o.amountPaid == 0 && o.totalPrice > 0;
          case 'All':
          default:
            return true;
        }
      }).toList();

      // 3. Date Range Filter
      filtered = filtered.where((o) {
        switch (filter.dateRange) {
          case 'Today':
            return o.createdAt.year == now.year &&
                o.createdAt.month == now.month &&
                o.createdAt.day == now.day;
          case 'This Week':
            final monday = now.subtract(Duration(days: now.weekday - 1));
            final startOfWeek = DateTime(monday.year, monday.month, monday.day);
            final endOfWeek = startOfWeek.add(const Duration(days: 7));
            return o.createdAt.isAfter(startOfWeek) && o.createdAt.isBefore(endOfWeek);
          case 'This Month':
            return o.createdAt.year == now.year && o.createdAt.month == now.month;
          case 'Custom':
            if (filter.customDateRange == null) return true;
            final start = DateTime(
              filter.customDateRange!.start.year,
              filter.customDateRange!.start.month,
              filter.customDateRange!.start.day,
            );
            final end = DateTime(
              filter.customDateRange!.end.year,
              filter.customDateRange!.end.month,
              filter.customDateRange!.end.day,
              23,
              59,
              59,
            );
            return o.createdAt.isAfter(start.subtract(const Duration(seconds: 1))) &&
                o.createdAt.isBefore(end.add(const Duration(seconds: 1)));
          case 'All Time':
          default:
            return true;
        }
      }).toList();

      // Sort by creation date descending
      filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return AsyncValue.data(filtered);
    },
  );
});
