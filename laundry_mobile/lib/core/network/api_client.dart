import 'package:dio/dio.dart';
import 'dart:io';

class ApiClient {
  late final Dio _dio;
  
  // Use 10.0.2.2 for Android Emulator, 127.0.0.1 for desktop/iOS
  final String _baseUrl = Platform.isAndroid 
      ? 'http://10.0.2.2:8000/api'
      : 'http://127.0.0.1:8000/api';

  ApiClient() {
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
      onRequest: (options, handler) {
        // TODO: Inject Auth Token here when authentication is implemented
        return handler.next(options);
      },
      onError: (DioException e, handler) {
        // Global error logging
        print('API Error: ${e.response?.statusCode} - ${e.message}');
        return handler.next(e);
      },
    ));
  }

  Dio get dio => _dio;
}
