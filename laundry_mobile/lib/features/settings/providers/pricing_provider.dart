import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/local_db/database_helper.dart';
import '../../../core/models/category_model.dart';
import '../../../core/models/service_type_model.dart';
import '../../../core/models/item_pricing_model.dart';
import '../../../core/providers.dart';

final dbHelperProvider = Provider((ref) => DatabaseHelper.instance);

final categoriesProvider = FutureProvider<List<CategoryModel>>((ref) async {
  final db = await ref.watch(dbHelperProvider).database;
  final results = await db.query('categories', where: 'is_deleted = ?', whereArgs: [0]);
  return results.map((e) => CategoryModel.fromDb(e)).toList();
});

final serviceTypesProvider = FutureProvider<List<ServiceTypeModel>>((ref) async {
  final db = await ref.watch(dbHelperProvider).database;
  final results = await db.query('service_types', where: 'is_deleted = ?', whereArgs: [0]);
  return results.map((e) => ServiceTypeModel.fromDb(e)).toList();
});

final itemPricingProvider = FutureProvider<List<ItemPricingModel>>((ref) async {
  final db = await ref.watch(dbHelperProvider).database;
  final results = await db.query('item_pricing', where: 'is_deleted = ?', whereArgs: [0]);
  return results.map((e) => ItemPricingModel.fromDb(e)).toList();
});

class ConfigurationController {
  final Ref ref;
  final DatabaseHelper dbHelper;

  ConfigurationController(this.ref, this.dbHelper);

  Future<void> addCategory(String name) async {
    final category = CategoryModel(
      id: const Uuid().v4(),
      name: name,
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
      syncStatus: 'pending',
    );
    await dbHelper.insertCategory(category.toDb());
    ref.invalidate(categoriesProvider);
    ref.read(syncRepositoryProvider).triggerSync();
  }

  Future<void> editCategory(CategoryModel category, String newName) async {
    final updated = CategoryModel(
      id: category.id,
      name: newName,
      createdAt: category.createdAt,
      updatedAt: DateTime.now().toUtc(),
      syncStatus: 'pending',
    );
    await dbHelper.insertCategory(updated.toDb());
    ref.invalidate(categoriesProvider);
    ref.read(syncRepositoryProvider).triggerSync();
  }

  Future<void> deleteCategory(CategoryModel category) async {
    final updated = CategoryModel(
      id: category.id,
      name: category.name,
      createdAt: category.createdAt,
      updatedAt: DateTime.now().toUtc(),
      isDeleted: true,
      syncStatus: 'pending',
    );
    await dbHelper.insertCategory(updated.toDb());
    ref.invalidate(categoriesProvider);
    ref.read(syncRepositoryProvider).triggerSync();
  }

  Future<void> addServiceType(String name, String description) async {
    final serviceType = ServiceTypeModel(
      id: const Uuid().v4(),
      name: name,
      description: description,
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
      syncStatus: 'pending',
    );
    await dbHelper.insertServiceType(serviceType.toDb());
    ref.invalidate(serviceTypesProvider);
    ref.read(syncRepositoryProvider).triggerSync();
  }

  Future<void> editServiceType(ServiceTypeModel serviceType, String newName, String newDesc) async {
    final updated = ServiceTypeModel(
      id: serviceType.id,
      name: newName,
      description: newDesc,
      createdAt: serviceType.createdAt,
      updatedAt: DateTime.now().toUtc(),
      syncStatus: 'pending',
    );
    await dbHelper.insertServiceType(updated.toDb());
    ref.invalidate(serviceTypesProvider);
    ref.read(syncRepositoryProvider).triggerSync();
  }

  Future<void> deleteServiceType(ServiceTypeModel serviceType) async {
    final updated = ServiceTypeModel(
      id: serviceType.id,
      name: serviceType.name,
      description: serviceType.description,
      createdAt: serviceType.createdAt,
      updatedAt: DateTime.now().toUtc(),
      isDeleted: true,
      syncStatus: 'pending',
    );
    await dbHelper.insertServiceType(updated.toDb());
    ref.invalidate(serviceTypesProvider);
    ref.read(syncRepositoryProvider).triggerSync();
  }

  Future<void> addItemPricing(String name, double price, String categoryId, String serviceTypeId) async {
    final pricing = ItemPricingModel(
      id: const Uuid().v4(),
      name: name,
      price: price,
      categoryId: categoryId,
      serviceTypeId: serviceTypeId,
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
      syncStatus: 'pending',
    );
    await dbHelper.insertItemPricing(pricing.toDb());
    ref.invalidate(itemPricingProvider);
    ref.read(syncRepositoryProvider).triggerSync();
  }

  Future<void> editItemPricing(ItemPricingModel pricing, String newName, double newPrice, String newCategoryId, String newServiceTypeId) async {
    final updated = ItemPricingModel(
      id: pricing.id,
      name: newName,
      price: newPrice,
      categoryId: newCategoryId,
      serviceTypeId: newServiceTypeId,
      createdAt: pricing.createdAt,
      updatedAt: DateTime.now().toUtc(),
      syncStatus: 'pending',
    );
    await dbHelper.insertItemPricing(updated.toDb());
    ref.invalidate(itemPricingProvider);
    ref.read(syncRepositoryProvider).triggerSync();
  }

  Future<void> deleteItemPricing(ItemPricingModel pricing) async {
    final updated = ItemPricingModel(
      id: pricing.id,
      name: pricing.name,
      price: pricing.price,
      categoryId: pricing.categoryId,
      serviceTypeId: pricing.serviceTypeId,
      createdAt: pricing.createdAt,
      updatedAt: DateTime.now().toUtc(),
      isDeleted: true,
      syncStatus: 'pending',
    );
    await dbHelper.insertItemPricing(updated.toDb());
    ref.invalidate(itemPricingProvider);
    ref.read(syncRepositoryProvider).triggerSync();
  }
}

final configurationControllerProvider = Provider<ConfigurationController>((ref) {
  return ConfigurationController(ref, ref.watch(dbHelperProvider));
});

