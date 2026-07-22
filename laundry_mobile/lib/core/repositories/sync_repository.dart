import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import '../models/customer_model.dart';
import '../providers.dart';
import '../../features/customers/providers/customer_providers.dart';
import '../../features/settings/providers/pricing_provider.dart';

class SyncRepository {
  final Ref _ref;
  final ApiService _apiService = ApiService();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  Future<void>? _activeSyncFuture;

  SyncRepository(this._ref);

  /// Fire-and-forget sync (used by non-dashboard screens).
  void triggerSync() {
    _activeSyncFuture ??= _performDeltaSync().whenComplete(() {
      _activeSyncFuture = null;
    });
  }

  /// Awaitable sync — blocks until fresh data is written to the DB.
  /// If a sync is already running it reuses that same future (no double request).
  /// If the cooldown means we skip the network call it returns immediately so
  /// the dashboard can at least show locally-stored data.
  Future<void> awaitSync() {
    if (_activeSyncFuture != null) return _activeSyncFuture!;
    _activeSyncFuture = _performDeltaSync().whenComplete(() {
      _activeSyncFuture = null;
    });
    return _activeSyncFuture!;
  }

  Future<List<OrderModel>> getOrders() async {
    final db = await _dbHelper.database;
    final localData = await db.query('orders', where: 'is_deleted = ?', whereArgs: [0]);
    final localOrders = localData.map((e) => OrderModel.fromDb(e)).toList();

    _performDeltaSync(); // Trigger background sync
    return localOrders;
  }

  Future<void> _performDeltaSync() async {
    if (_isSyncing) return;

    if (_lastSyncTime != null && DateTime.now().difference(_lastSyncTime!) < const Duration(seconds: 10)) {
      return;
    }

    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult.isEmpty || connectivityResult.contains(ConnectivityResult.none)) return;

    _isSyncing = true;
    _ref.read(syncStatusProvider.notifier).setSyncing();
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 1. Push pending records
      final pendingRecords = await _dbHelper.getPendingSyncRecords();
      if ((pendingRecords['orders'] as List).isNotEmpty || 
          (pendingRecords['order_items'] as List).isNotEmpty ||
          (pendingRecords['categories'] as List).isNotEmpty ||
          (pendingRecords['service_types'] as List).isNotEmpty ||
          (pendingRecords['item_pricing'] as List).isNotEmpty ||
          (pendingRecords['customers'] as List).isNotEmpty) {
        await _apiService.pushDelta(pendingRecords);
        await _dbHelper.markRecordsAsSynced();
      }

      // 2. Pull delta
      final lastSync = prefs.getString('last_sync_timestamp');
      final deltaPayload = await _apiService.syncDelta(lastSync);
      final db = await _dbHelper.database;
      
      sqflite.Batch batch = db.batch();

      // Process Customers
      final pendingCustomers = await db.query('customers', where: 'sync_status = ?', whereArgs: ['pending']);
      final pendingCustomerIds = pendingCustomers.map((e) => e['id'] as String).toSet();
      for (var json in (deltaPayload['customers'] as List? ?? [])) {
        final item = CustomerModel.fromJson(json);
        if (pendingCustomerIds.contains(item.id)) continue;
        if (item.isDeleted) {
          batch.delete('customers', where: 'id = ?', whereArgs: [item.id]);
        } else {
          batch.insert('customers', item.toDb(), conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
        }
      }

      // Process Orders
      final pendingOrders = await db.query('orders', where: 'sync_status = ?', whereArgs: ['pending']);
      final pendingOrderIds = pendingOrders.map((e) => e['id'] as String).toSet();
      for (var json in (deltaPayload['orders'] as List? ?? [])) {
        final item = OrderModel.fromJson(json);
        if (pendingOrderIds.contains(item.id)) continue;
        if (item.isDeleted) {
          batch.delete('orders', where: 'id = ?', whereArgs: [item.id]);
        } else {
          batch.insert('orders', item.toDb(), conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
        }
      }

      // Process Service Types
      final pendingServiceTypes = await db.query('service_types', where: 'sync_status = ?', whereArgs: ['pending']);
      final pendingServiceTypeIds = pendingServiceTypes.map((e) => e['id'] as String).toSet();
      for (var json in (deltaPayload['service_types'] as List? ?? [])) {
        final item = ServiceTypeModel.fromJson(json);
        if (pendingServiceTypeIds.contains(item.id)) continue;
        if (item.isDeleted) {
          batch.delete('service_types', where: 'id = ?', whereArgs: [item.id]);
        } else {
          batch.insert('service_types', item.toDb(), conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
        }
      }

      // Process Categories
      final pendingCategories = await db.query('categories', where: 'sync_status = ?', whereArgs: ['pending']);
      final pendingCategoryIds = pendingCategories.map((e) => e['id'] as String).toSet();
      for (var json in (deltaPayload['categories'] as List? ?? [])) {
        final item = CategoryModel.fromJson(json);
        if (pendingCategoryIds.contains(item.id)) continue;
        if (item.isDeleted) {
          batch.delete('categories', where: 'id = ?', whereArgs: [item.id]);
        } else {
          batch.insert('categories', item.toDb(), conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
        }
      }

      // Process Item Pricing
      final pendingItemPricing = await db.query('item_pricing', where: 'sync_status = ?', whereArgs: ['pending']);
      final pendingItemPricingIds = pendingItemPricing.map((e) => e['id'] as String).toSet();
      for (var json in (deltaPayload['item_pricing'] as List? ?? [])) {
        final item = ItemPricingModel.fromJson(json);
        if (pendingItemPricingIds.contains(item.id)) continue;
        if (item.isDeleted) {
          batch.delete('item_pricing', where: 'id = ?', whereArgs: [item.id]);
        } else {
          batch.insert('item_pricing', item.toDb(), conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
        }
      }

      // Process Order Statuses
      final pendingOrderStatus = await db.query('order_statuses', where: 'sync_status = ?', whereArgs: ['pending']);
      final pendingOrderStatusIds = pendingOrderStatus.map((e) => e['id'] as String).toSet();
      for (var json in (deltaPayload['order_statuses'] as List? ?? [])) {
        final item = OrderStatusModel.fromJson(json);
        if (pendingOrderStatusIds.contains(item.id)) continue;
        if (item.isDeleted) {
          batch.delete('order_statuses', where: 'id = ?', whereArgs: [item.id]);
        } else {
          batch.insert('order_statuses', item.toDb(), conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
        }
      }

      // Process Order Items
      final pendingOrderItems = await db.query('order_items', where: 'sync_status = ?', whereArgs: ['pending']);
      final pendingOrderItemIds = pendingOrderItems.map((e) => e['id'] as String).toSet();
      for (var json in (deltaPayload['order_items'] as List? ?? [])) {
        final item = OrderItemModel.fromJson(json);
        if (pendingOrderItemIds.contains(item.id)) continue;
        if (item.isDeleted) {
          batch.delete('order_items', where: 'id = ?', whereArgs: [item.id]);
        } else {
          batch.insert('order_items', item.toDb(), conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
        }
      }

      await batch.commit(noResult: true);
      
      // Invalidate customersProvider to ensure Customers list is refreshed with synced records
      _ref.invalidate(customersProvider);
      _ref.invalidate(categoriesProvider);
      _ref.invalidate(serviceTypesProvider);
      _ref.invalidate(itemPricingProvider);
      
      // Update timestamp to current UTC time
      await prefs.setString('last_sync_timestamp', DateTime.now().toUtc().toIso8601String());
      
      _lastSyncTime = DateTime.now();
      _ref.read(syncStatusProvider.notifier).setSuccess(_lastSyncTime!);
      _ref.read(lastSyncTimestampProvider.notifier).update(_lastSyncTime);
    } catch (e) {
      print('Delta Sync failed: $e');
      _ref.read(syncStatusProvider.notifier).setError(e.toString());
    } finally {
      _isSyncing = false;
    }
  }
}
