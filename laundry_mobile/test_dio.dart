import 'package:dio/dio.dart';
void main() async {
  final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 60)));
  print('Timeout set to: ${dio.options.connectTimeout}');
  try {
    await dio.get('http://10.255.255.1');
  } catch (e) {
    print(e.toString());
  }
}
