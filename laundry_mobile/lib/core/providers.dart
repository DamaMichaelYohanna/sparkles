import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'network/api_service.dart';
import 'repositories/sync_repository.dart';
import 'local_db/database_helper.dart';

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService();
});

final syncRepositoryProvider = Provider<SyncRepository>((ref) {
  return SyncRepository();
});

final officeNameProvider = FutureProvider.autoDispose<String>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('office_name') ?? 'My Laundry Co.';
});

final pendingSyncCountProvider = StreamProvider.autoDispose<int>((ref) async* {
  final db = await DatabaseHelper.instance.database;
  while (true) {
    final ordersResult = await db.rawQuery("SELECT COUNT(*) as count FROM orders WHERE sync_status = 'pending'");
    final orderItemsResult = await db.rawQuery("SELECT COUNT(*) as count FROM order_items WHERE sync_status = 'pending'");
    final count = (Sqflite.firstIntValue(ordersResult) ?? 0) + (Sqflite.firstIntValue(orderItemsResult) ?? 0);
    yield count;
    await Future.delayed(const Duration(seconds: 4));
  }
});
