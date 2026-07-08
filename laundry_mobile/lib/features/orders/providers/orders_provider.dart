import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laundry_mobile/core/models/order_model.dart';
import 'package:laundry_mobile/core/providers.dart';

final ordersListProvider = FutureProvider.autoDispose<List<OrderModel>>((ref) async {
  final syncRepo = ref.watch(syncRepositoryProvider);
  return await syncRepo.getOrders();
});
