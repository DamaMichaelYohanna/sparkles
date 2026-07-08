import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

class ApiService {
  late final Dio _dio;

  // Production URL on Vercel
  final String _baseUrl = 'https://sparkles-green.vercel.app/api';

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('access_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) {
        print('API Error: ${e.response?.statusCode} - ${e.message}');
        if (e.response?.statusCode == 403) {
          // Handle TierLimitPermission or general 403s
          final message = e.response?.data?['detail'] ?? "Subscription limit reached or access denied.";
          return handler.next(DioException(
            requestOptions: e.requestOptions,
            response: e.response,
            type: e.type,
            error: Exception("TierLimitError: $message"),
          ));
        }
        return handler.next(e);
      },
    ));
  }

  Future<String?> login(String username, String password) async {
    try {
      final response = await _dio.post('/token/', data: {
        'username': username,
        'password': password,
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', response.data['access']);
      await prefs.setString('refresh_token', response.data['refresh']);
      return response.data['access'];
    } catch (e) {
      print('Login failed: $e');
      return null;
    }
  }

  Future<List<dynamic>> getOrders() async {
    try {
      final response = await _dio.get('/orders/');
      // Pagination parsing if applicable, though for sync we use /api/sync/
      if (response.data is Map && response.data.containsKey('results')) {
        return response.data['results'] as List<dynamic>;
      }
      return response.data as List<dynamic>;
    } catch (e) {
      throw Exception('Failed to load orders: $e');
    }
  }

  Future<Map<String, dynamic>> syncDelta(String? lastSyncTimestamp) async {
    try {
      final response = await _dio.get('/sync/', queryParameters: {
        if (lastSyncTimestamp != null) 'last_sync_timestamp': lastSyncTimestamp,
      });
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to sync delta: $e');
    }
  }

  Future<Map<String, dynamic>> pushDelta(Map<String, dynamic> payload) async {
    try {
      final response = await _dio.post('/sync/', data: payload);
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to push delta: $e');
    }
  }

  Future<Map<String, dynamic>> getDashboardOperations() async {
    try {
      final response = await _dio.get('/dashboard/operations/');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to load dashboard: $e');
    }
  }

  // Define other API methods as needed (Dashboard stats, etc)
}
