import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../core/models/dashboard_stats_model.dart';
import '../../core/models/order_model.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});

final dashboardStatsProvider = FutureProvider.autoDispose<DashboardStats>((ref) async {
  final api = ref.watch(apiClientProvider);
  
  try {
    final response = await api.dio.get('/dashboard/operations/');
    return DashboardStats.fromJson(response.data);
  } catch (e) {
    // Return empty stats on error or throw to let UI handle it
    print("Error fetching dashboard stats: $e");
    // For now, if the API isn't up, we throw to show error state, 
    // or we could return empty data. Let's throw.
    throw Exception('Failed to load dashboard stats');
  }
});

final recentOrdersProvider = FutureProvider.autoDispose<List<OrderModel>>((ref) async {
  final api = ref.watch(apiClientProvider);
  
  try {
    // Fetching orders, maybe limiting to recent ones
    final response = await api.dio.get('/orders/', queryParameters: {'limit': 5});
    
    // DRF usually paginates, so results might be in response.data['results']
    List<dynamic> data = [];
    if (response.data is Map && response.data.containsKey('results')) {
      data = response.data['results'];
    } else if (response.data is List) {
      data = response.data;
    }

    return data.map((json) => OrderModel.fromJson(json)).toList();
  } catch (e) {
    print("Error fetching recent orders: $e");
    throw Exception('Failed to load recent orders');
  }
});
