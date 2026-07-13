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
      throw _handleException(e, 'Failed to load orders');
    }
  }

  Future<Map<String, dynamic>> syncDelta(String? lastSyncTimestamp) async {
    try {
      final response = await _dio.get('sync/', queryParameters: {
        if (lastSyncTimestamp != null) 'last_sync_timestamp': lastSyncTimestamp,
      });
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw _handleException(e, 'Failed to sync delta');
    }
  }

  Future<Map<String, dynamic>> pushDelta(Map<String, dynamic> payload) async {
    try {
      final response = await _dio.post('sync/', data: payload);
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw _handleException(e, 'Failed to push delta');
    }
  }

  Future<Map<String, dynamic>> getDashboardOperations() async {
    try {
      final response = await _dio.get('dashboard/operations/');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw _handleException(e, 'Failed to load dashboard');
    }
  }

  Future<Map<String, dynamic>> getCurrentUserProfile() async {
    try {
      final response = await _dio.get('users/me/');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw _handleException(e, 'Failed to get current user profile');
    }
  }

  Future<List<dynamic>> getSubUsers() async {
    try {
      final response = await _dio.get('users/');
      return response.data as List<dynamic>;
    } catch (e) {
      throw _handleException(e, 'Failed to load sub-users');
    }
  }

  Future<Map<String, dynamic>> createSubUser(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post('users/', data: data);
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw _handleException(e, 'Failed to create user');
    }
  }

  Future<void> deleteSubUser(String id) async {
    try {
      await _dio.delete('users/$id/');
    } catch (e) {
      throw _handleException(e, 'Failed to delete user');
    }
  }

  Future<Map<String, dynamic>> initializeSubscription(String tier) async {
    try {
      final response = await _dio.post('billing/initialize/', data: {'tier': tier});
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw _handleException(e, 'Failed to initialize subscription');
    }
  }

  Future<Map<String, dynamic>> verifySubscription(String reference) async {
    try {
      final response = await _dio.get('billing/verify/', queryParameters: {'reference': reference});
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw _handleException(e, 'Failed to verify subscription');
    }
  }

  Future<Map<String, dynamic>> updateOfficeDetails(String officeId, Map<String, dynamic> data) async {
    try {
      final response = await _dio.patch('offices/$officeId/', data: data);
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw _handleException(e, 'Failed to update office details');
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
      throw _handleException(e, 'Failed to register');
    }
  }

  Future<Map<String, dynamic>> requestPasswordReset(String email) async {
    try {
      final response = await _dio.post('password-reset/request/', data: {
        'email': email,
      });
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw _handleException(e, 'Failed to request password reset');
    }
  }

  Future<Map<String, dynamic>> verifyPasswordResetOTP(String email, String otp) async {
    try {
      final response = await _dio.post('password-reset/verify/', data: {
        'email': email,
        'otp': otp,
      });
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw _handleException(e, 'Failed to verify verification code');
    }
  }

  Future<Map<String, dynamic>> confirmPasswordReset(String email, String otp, String password) async {
    try {
      final response = await _dio.post('password-reset/confirm/', data: {
        'email': email,
        'otp': otp,
        'password': password,
      });
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw _handleException(e, 'Failed to confirm password reset');
    }
  }

  Future<List<dynamic>> getBranches() async {
    try {
      final response = await _dio.get('branches/');
      return response.data as List<dynamic>;
    } catch (e) {
      throw _handleException(e, 'Failed to fetch branches');
    }
  }

  Future<Map<String, dynamic>> createBranch(String name, String contactInfo) async {
    try {
      final response = await _dio.post('branches/', data: {
        'name': name,
        'contact_info': contactInfo,
      });
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw _handleException(e, 'Failed to create branch');
    }
  }

  Future<Map<String, dynamic>> switchBranch(String officeId) async {
    try {
      final response = await _dio.post('branches/switch/', data: {
        'office_id': officeId,
      });
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw _handleException(e, 'Failed to switch branch');
    }
  }

  Exception _handleException(dynamic e, String defaultMessage) {
    if (e is DioException) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        return Exception('Connection timed out. Please check your internet connection and try again.');
      } else if (e.type == DioExceptionType.connectionError) {
        return Exception('No internet connection. Please check your network connection and try again.');
      } else if (e.response != null) {
        final data = e.response?.data;
        if (data is Map) {
          if (data.containsKey('error') && data['error'] != null) {
            final errorVal = data['error'];
            if (errorVal is Map) {
              final messages = errorVal.values
                  .map((v) => v is List ? v.join(', ') : v.toString())
                  .join('\n');
              if (messages.isNotEmpty) return Exception(messages);
            }
            return Exception(errorVal.toString());
          }
          if (data.containsKey('detail') && data['detail'] != null) {
            return Exception(data['detail'].toString());
          }
          if (data.containsKey('message') && data['message'] != null) {
            return Exception(data['message'].toString());
          }
          // Join validation error map (e.g., {"email": ["..."]})
          final List<String> fieldErrors = [];
          data.forEach((key, value) {
            final field = key.toString();
            final capitalizedField = field.isNotEmpty
                ? '${field[0].toUpperCase()}${field.substring(1)}'
                : field;
            if (value is List) {
              fieldErrors.add('$capitalizedField: ${value.join(", ")}');
            } else if (value is Map) {
              fieldErrors.add('$capitalizedField: ${value.values.join(", ")}');
            } else if (value != null) {
              fieldErrors.add('$capitalizedField: $value');
            }
          });
          if (fieldErrors.isNotEmpty) {
            return Exception(fieldErrors.join('\n'));
          }
        }
        return Exception(e.response?.statusMessage ?? 'Server error (${e.response?.statusCode})');
      }
    }
    if (e is Exception) {
      return e;
    }
    return Exception('$defaultMessage: $e');
  }
}
