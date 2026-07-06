import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

class ApiService {
  late final Dio _dio;

  // Use 10.0.2.2 for Android Emulator, 127.0.0.1 for desktop/iOS
  final String _baseUrl = Platform.isAndroid 
      ? 'http://10.0.2.2:8000/api'
      : 'http://127.0.0.1:8000/api';

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
      return response.data as List<dynamic>;
    } catch (e) {
      throw Exception('Failed to load orders: $e');
    }
  }

  // Define other API methods as needed (Dashboard stats, etc)
}
