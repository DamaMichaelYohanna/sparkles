import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

class ApiService {
  late final Dio _dio;

  // Production URL — sparkles.com.ng
  final String _baseUrl = 'https://www.sparkles.com.ng/api/';

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
      onError: (DioException e, handler) async {
        // Silent refresh: if 401 and we have a refresh token, retry once
        if (e.response?.statusCode == 401) {
          final prefs = await SharedPreferences.getInstance();
          final refreshToken = prefs.getString('refresh_token');
          if (refreshToken != null) {
            try {
              final refreshDio = Dio(BaseOptions(
                baseUrl: _baseUrl,
                connectTimeout: const Duration(seconds: 30),
                receiveTimeout: const Duration(seconds: 30),
                headers: {'Content-Type': 'application/json'},
              ));
              final resp = await refreshDio.post(
                'token/refresh/',
                data: {'refresh': refreshToken},
              );
              final newAccess = resp.data['access'] as String;
              // ROTATE_REFRESH_TOKENS=True means we may get a new refresh too
              final newRefresh = resp.data['refresh'] as String?;
              await prefs.setString('access_token', newAccess);
              if (newRefresh != null) {
                await prefs.setString('refresh_token', newRefresh);
              }
              // Retry the original request with the new token
              final retryOptions = e.requestOptions;
              retryOptions.headers['Authorization'] = 'Bearer $newAccess';
              final retryResponse = await _dio.fetch(retryOptions);
              return handler.resolve(retryResponse);
            } catch (_) {
              // Refresh failed — fall through to original error (app will handle logout)
            }
          }
        }
        print('API Error: ${e.response?.statusCode} - ${e.message}');
        if (e.response?.statusCode == 403) {
          final message = e.response?.data?['detail'] ?? "Subscription limit reached or access denied.";
          return handler.next(DioException(
            requestOptions: e.requestOptions,
            response: e.response,
            type: e.type,
            error: UserFriendlyException(message),
          ));
        }
        return handler.next(e);
      },
    ));
  }

  /// Attempt a silent token refresh using the stored refresh token.
  /// Returns true if successful, false if the user needs to log in again.
  Future<bool> silentRefresh() async {
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString('refresh_token');
    if (refreshToken == null) return false;
    try {
      final response = await _dio.post('token/refresh/', data: {'refresh': refreshToken});
      final newAccess = response.data['access'] as String;
      final newRefresh = response.data['refresh'] as String?;
      await prefs.setString('access_token', newAccess);
      if (newRefresh != null) {
        await prefs.setString('refresh_token', newRefresh);
      }
      return true;
    } catch (_) {
      return false;
    }
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
        return UserFriendlyException('Connection timed out. Please check your internet connection and try again.');
      } else if (e.type == DioExceptionType.connectionError) {
        return UserFriendlyException('No internet connection. Please check your network connection and try again.');
      } else if (e.response != null) {
        final statusCode = e.response?.statusCode;
        
        if (statusCode == 500) {
          return UserFriendlyException('Something went wrong on our servers. Please try again in a few moments.');
        } else if (statusCode == 502 || statusCode == 503 || statusCode == 504) {
          return UserFriendlyException('Server is temporarily unreachable. Please try again shortly.');
        } else if (statusCode == 404) {
          return UserFriendlyException('Requested resource not found. Please verify and try again.');
        } else if (statusCode == 401) {
          return UserFriendlyException('Session expired or unauthorized. Please sign out and sign in again.');
        } else if (statusCode == 403) {
          return UserFriendlyException('Access denied. You do not have permission to perform this action.');
        }
        
        final data = e.response?.data;
        if (data is Map) {
          if (data.containsKey('error') && data['error'] != null) {
            final errorVal = data['error'];
            if (errorVal is Map) {
              final messages = errorVal.values
                  .map((v) => v is List ? v.join(', ') : v.toString())
                  .join('\n');
              if (messages.isNotEmpty) return UserFriendlyException(messages);
            }
            return UserFriendlyException(errorVal.toString());
          }
          if (data.containsKey('detail') && data['detail'] != null) {
            return UserFriendlyException(data['detail'].toString());
          }
          if (data.containsKey('message') && data['message'] != null) {
            return UserFriendlyException(data['message'].toString());
          }
          // Join validation error map (e.g., {"email": ["..."]})
          final List<String> fieldErrors = [];
          data.forEach((key, value) {
            final field = key.toString();
            if (field == 'id' || field == 'office_id') return;
            
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
            return UserFriendlyException(fieldErrors.join('\n'));
          }
        }
        return UserFriendlyException(e.response?.statusMessage ?? 'Server error ($statusCode). Please try again.');
      }
    }
    
    String errorString = e.toString();
    if (errorString.contains('SocketException') || 
        errorString.contains('HandshakeException') ||
        errorString.contains('HttpException')) {
      return UserFriendlyException('Network connectivity error. Please check your internet connection.');
    }
    
    if (e is Exception) {
      final message = errorString.replaceAll('Exception:', '').trim();
      if (message.isNotEmpty) return UserFriendlyException(message);
      return e;
    }
    
    return UserFriendlyException('$defaultMessage. Please check your connection and try again.');
  }
}

class UserFriendlyException implements Exception {
  final String message;
  UserFriendlyException(this.message);

  @override
  String toString() => message;
}
