import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/order_model.dart';
import '../../dashboard/providers/dashboard_provider.dart'; // for apiClientProvider

final ordersListProvider = FutureProvider.autoDispose<List<OrderModel>>((ref) async {
  final api = ref.watch(apiClientProvider);
  
  try {
    final response = await api.dio.get('/orders/');
    
    List<dynamic> data = [];
    if (response.data is Map && response.data.containsKey('results')) {
      data = response.data['results'];
    } else if (response.data is List) {
      data = response.data;
    }

    return data.map((json) => OrderModel.fromJson(json)).toList();
  } catch (e) {
    print("Error fetching orders: $e");
    throw Exception('Failed to load orders');
  }
});
