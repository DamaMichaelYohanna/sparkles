import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/local_db/database_helper.dart';
import '../../../core/models/customer_model.dart';
import '../../../core/providers.dart';

class CustomersListNotifier extends Notifier<AsyncValue<List<CustomerModel>>> {
   final DatabaseHelper _dbHelper = DatabaseHelper.instance;

   @override
   AsyncValue<List<CustomerModel>> build() {
     Future.microtask(() => loadCustomers());
     return const AsyncValue.loading();
   }

   Future<void> loadCustomers() async {
     state = const AsyncValue.loading();
     try {
       final list = await _dbHelper.getCustomers();
       final customers = list.map((e) => CustomerModel.fromDb(e)).toList();
       state = AsyncValue.data(customers);
     } catch (e, stack) {
       state = AsyncValue.error(e, stack);
     }
   }

    Future<CustomerModel> createCustomer({
      required String name,
      required String phone,
      bool isWhatsapp = false,
    }) async {
      final now = DateTime.now().toUtc();
      final customer = CustomerModel(
        id: const Uuid().v4(),
        name: name,
        phone: phone,
        isWhatsapp: isWhatsapp,
        createdAt: now,
        updatedAt: now,
        syncStatus: 'pending',
      );

      await _dbHelper.insertCustomer(customer.toDb());
      await loadCustomers();
      
      // Trigger sync repository in background
      ref.read(syncRepositoryProvider).triggerSync();
      
      return customer;
    }

    Future<void> updateCustomer(CustomerModel customer) async {
      final updated = customer.copyWith(
        updatedAt: DateTime.now().toUtc(),
        syncStatus: 'pending',
      );

      await _dbHelper.insertCustomer(updated.toDb());
      await loadCustomers();

      // Trigger sync repository in background
      ref.read(syncRepositoryProvider).triggerSync();
    }

    Future<void> deleteCustomer(String id) async {
      final db = await _dbHelper.database;
      final now = DateTime.now().toUtc().toIso8601String();
      
      await db.update(
        'customers',
        {
          'is_deleted': 1,
          'updated_at': now,
          'sync_status': 'pending',
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      
      await loadCustomers();
      ref.read(syncRepositoryProvider).triggerSync();
    }
}

final customersProvider = NotifierProvider<CustomersListNotifier, AsyncValue<List<CustomerModel>>>(() {
  return CustomersListNotifier();
});

class CustomerSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';
}

final customerSearchQueryProvider = NotifierProvider<CustomerSearchQueryNotifier, String>(() {
  return CustomerSearchQueryNotifier();
});

final filteredCustomersProvider = Provider<AsyncValue<List<CustomerModel>>>((ref) {
  final customersState = ref.watch(customersProvider);
  final searchQuery = ref.watch(customerSearchQueryProvider).toLowerCase().trim();

  return customersState.when(
    data: (list) {
      if (searchQuery.isEmpty) return AsyncValue.data(list);
      
      final filtered = list.where((c) {
        return c.name.toLowerCase().contains(searchQuery) ||
               c.phone.toLowerCase().contains(searchQuery);
      }).toList();
      
      return AsyncValue.data(filtered);
    },
    loading: () => const AsyncValue.loading(),
    error: (e, stack) => AsyncValue.error(e, stack),
  );
});
