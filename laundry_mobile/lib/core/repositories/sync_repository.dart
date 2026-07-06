import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import '../local_db/database_helper.dart';
import '../network/api_service.dart';
import '../models/order_model.dart';

class SyncRepository {
  final ApiService _apiService = ApiService();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<List<OrderModel>> getOrders() async {
    final db = await _dbHelper.database;

    // 1. First, get from local DB for instant offline response
    final localData = await db.query('orders');
    final localOrders = localData.map((e) => OrderModel.fromDb(e)).toList();

    // 2. Trigger background sync if online
    _syncOrdersInBackground();

    return localOrders;
  }

  Future<void> _syncOrdersInBackground() async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult == ConnectivityResult.none) {
      return; // Offline, can't sync
    }

    try {
      final remoteData = await _apiService.getOrders();
      final db = await _dbHelper.database;
      
      // Update local database with remote data
      Batch batch = db.batch();
      for (var json in remoteData) {
        final order = OrderModel.fromJson(json);
        batch.insert('orders', order.toDb(), conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
      
      // Optionally notify listeners or use Riverpod to invalidate the provider
    } catch (e) {
      print('Sync failed: $e');
    }
  }

  // Define other sync methods for Dashboard Stats, Offices, etc.
}
