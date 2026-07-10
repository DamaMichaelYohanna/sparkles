import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:shared_preferences/shared_preferences.dart';
import '../local_db/database_helper.dart';
import '../network/api_service.dart';
import '../models/order_model.dart';
import '../models/service_type_model.dart';
import '../models/category_model.dart';
import '../models/item_pricing_model.dart';
import '../models/order_status_model.dart';
import '../models/order_item_model.dart';

class SyncRepository {
  final ApiService _apiService = ApiService();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<List<OrderModel>> getOrders() async {
    final db = await _dbHelper.database;
    final localData = await db.query('orders', where: 'is_deleted = ?', whereArgs: [0]);
    final localOrders = localData.map((e) => OrderModel.fromDb(e)).toList();

    _performDeltaSync(); // Trigger background sync
    return localOrders;
  }

  Future<void> _performDeltaSync() async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult.isEmpty || connectivityResult.contains(ConnectivityResult.none)) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 1. Push pending records
      final pendingRecords = await _dbHelper.getPendingSyncRecords();
      if ((pendingRecords['orders'] as List).isNotEmpty || 
          (pendingRecords['order_items'] as List).isNotEmpty ||
          (pendingRecords['categories'] as List).isNotEmpty ||
          (pendingRecords['service_types'] as List).isNotEmpty ||
          (pendingRecords['item_pricing'] as List).isNotEmpty) {
        await _apiService.pushDelta(pendingRecords);
        await _dbHelper.markRecordsAsSynced();
      }

      // 2. Pull delta
      final lastSync = prefs.getString('last_sync_timestamp');
      final deltaPayload = await _apiService.syncDelta(lastSync);
      final db = await _dbHelper.database;
      
      sqflite.Batch batch = db.batch();

      // Process Orders
      for (var json in (deltaPayload['orders'] as List? ?? [])) {
        final item = OrderModel.fromJson(json);
        if (item.isDeleted) {
          batch.delete('orders', where: 'id = ?', whereArgs: [item.id]);
        } else {
          batch.insert('orders', item.toDb(), conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
        }
      }

      // Process Service Types
      for (var json in (deltaPayload['service_types'] as List? ?? [])) {
        final item = ServiceTypeModel.fromJson(json);
        if (item.isDeleted) {
          batch.delete('service_types', where: 'id = ?', whereArgs: [item.id]);
        } else {
          batch.insert('service_types', item.toDb(), conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
        }
      }

      // Process Categories
      for (var json in (deltaPayload['categories'] as List? ?? [])) {
        final item = CategoryModel.fromJson(json);
        if (item.isDeleted) {
          batch.delete('categories', where: 'id = ?', whereArgs: [item.id]);
        } else {
          batch.insert('categories', item.toDb(), conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
        }
      }

      // Process Item Pricing
      for (var json in (deltaPayload['item_pricing'] as List? ?? [])) {
        final item = ItemPricingModel.fromJson(json);
        if (item.isDeleted) {
          batch.delete('item_pricing', where: 'id = ?', whereArgs: [item.id]);
        } else {
          batch.insert('item_pricing', item.toDb(), conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
        }
      }

      // Process Order Statuses
      for (var json in (deltaPayload['order_statuses'] as List? ?? [])) {
        final item = OrderStatusModel.fromJson(json);
        if (item.isDeleted) {
          batch.delete('order_statuses', where: 'id = ?', whereArgs: [item.id]);
        } else {
          batch.insert('order_statuses', item.toDb(), conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
        }
      }

      // Process Order Items
      for (var json in (deltaPayload['order_items'] as List? ?? [])) {
        final item = OrderItemModel.fromJson(json);
        if (item.isDeleted) {
          batch.delete('order_items', where: 'id = ?', whereArgs: [item.id]);
        } else {
          batch.insert('order_items', item.toDb(), conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
        }
      }

      await batch.commit(noResult: true);
      
      // Update timestamp to current UTC time
      await prefs.setString('last_sync_timestamp', DateTime.now().toUtc().toIso8601String());
      
    } catch (e) {
      print('Delta Sync failed: $e');
    }
  }
}
