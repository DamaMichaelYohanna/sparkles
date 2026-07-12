import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

class ApiService {
  late final Dio _dio;

  // Production URL on Vercel
  final String _baseUrl = 'https://sparkles-green.vercel.app/api/';

  ApiService() {
    print(">>> API_SERVICE INITIALIZED WITH 60s TIMEOUT <<<");
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 60),
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
    print('Attempting login to $_baseUrl with username: $username');
    try {
      final response = await _dio.post('token/', data: {
        'username': username,
        'password': password,
      });
      print('Login success! Status code: ${response.statusCode}');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', response.data['access']);
      await prefs.setString('refresh_token', response.data['refresh']);
      return response.data['access'];
    } catch (e) {
      if (e is DioException) {
        print('Login DioException: ${e.message}');
        print('Request URL was: ${e.requestOptions.uri}');
        if (e.response != null) {
          print('Response Status: ${e.response?.statusCode}');
          print('Response Data: ${e.response?.data}');
        }
      } else {
        print('Login failed with unknown error: $e');
      }
      return null;
    }
  }

  Future<List<dynamic>> getOrders() async {
    try {
      final response = await _dio.get('orders/');
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
      final response = await _dio.get('sync/', queryParameters: {
        if (lastSyncTimestamp != null) 'last_sync_timestamp': lastSyncTimestamp,
      });
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to sync delta: $e');
    }
  }

  Future<Map<String, dynamic>> pushDelta(Map<String, dynamic> payload) async {
    try {
      final response = await _dio.post('sync/', data: payload);
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to push delta: $e');
    }
  }

  Future<Map<String, dynamic>> getDashboardOperations() async {
    try {
      final response = await _dio.get('dashboard/operations/');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to load dashboard: $e');
    }
  }

  Future<Map<String, dynamic>> getCurrentUserProfile() async {
    try {
      final response = await _dio.get('users/me/');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to get current user profile: $e');
    }
  }

  Future<List<dynamic>> getSubUsers() async {
    try {
      final response = await _dio.get('users/');
      return response.data as List<dynamic>;
    } catch (e) {
      throw Exception('Failed to load sub-users: $e');
    }
  }

  Future<Map<String, dynamic>> createSubUser(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post('users/', data: data);
      return response.data as Map<String, dynamic>;
    } catch (e) {
      if (e is DioException && e.response != null) {
        final detail = e.response?.data?['detail'] ?? e.response?.data?.toString();
        if (detail != null) {
          throw Exception(detail);
        }
      }
      throw Exception('Failed to create user: $e');
    }
  }

  Future<void> deleteSubUser(String id) async {
    try {
      await _dio.delete('users/$id/');
    } catch (e) {
      throw Exception('Failed to delete user: $e');
    }
  }

  Future<Map<String, dynamic>> initializeSubscription(String tier) async {
    try {
      final response = await _dio.post('billing/initialize/', data: {'tier': tier});
      return response.data as Map<String, dynamic>;
    } catch (e) {
      if (e is DioException && e.response != null) {
        final error = e.response?.data?['error'] ?? e.response?.data?.toString();
        if (error != null) throw Exception(error);
      }
      throw Exception('Failed to initialize subscription: $e');
    }
  }

  Future<Map<String, dynamic>> verifySubscription(String reference) async {
    try {
      final response = await _dio.get('billing/verify/', queryParameters: {'reference': reference});
      return response.data as Map<String, dynamic>;
    } catch (e) {
      if (e is DioException && e.response != null) {
        final error = e.response?.data?['error'] ?? e.response?.data?.toString();
        if (error != null) throw Exception(error);
      }
      throw Exception('Failed to verify subscription: $e');
    }
  }

  Future<Map<String, dynamic>> updateOfficeDetails(String officeId, Map<String, dynamic> data) async {
    try {
      final response = await _dio.patch('offices/$officeId/', data: data);
      return response.data as Map<String, dynamic>;
    } catch (e) {
      if (e is DioException && e.response != null) {
        final detail = e.response?.data?['detail'] ?? e.response?.data?.toString();
        if (detail != null) throw Exception(detail);
      }
      throw Exception('Failed to update office details: $e');
    }
  }

  Future<Map<String, dynamic>> registerOffice(String officeName, String email, String password) async {
    try {
      final response = await _dio.post('register/', data: {
        'office_name': officeName,
        'email': email,
        'password': password,
      });
      return response.data as Map<String, dynamic>;
    } catch (e) {
      if (e is DioException && e.response != null) {
        final error = e.response?.data?['error'] ?? e.response?.data?.toString();
        if (error != null) throw Exception(error);
      }
      throw Exception('Failed to register: $e');
    }
  }
}
