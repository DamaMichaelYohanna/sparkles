import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'network/api_service.dart';
import 'repositories/sync_repository.dart';
import 'local_db/database_helper.dart';

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService();
});

class LastSyncTimestampNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  void update(DateTime? value) {
    state = value;
  }
}

final lastSyncTimestampProvider = NotifierProvider<LastSyncTimestampNotifier, DateTime?>(() {
  return LastSyncTimestampNotifier();
});

final syncRepositoryProvider = Provider<SyncRepository>((ref) {
  return SyncRepository(ref);
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

final userProfileProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  final profile = await api.getCurrentUserProfile();
  
  final prefs = await SharedPreferences.getInstance();
  if (profile['office_name'] != null) {
    await prefs.setString('office_name', profile['office_name']);
  }
  if (profile['office_contact_info'] != null) {
    await prefs.setString('office_contact', profile['office_contact_info']);
  }
  
  return profile;
});

final isAdminProvider = Provider.autoDispose<bool>((ref) {
  final profileAsync = ref.watch(userProfileProvider);
  return profileAsync.maybeWhen(
    data: (profile) => profile['is_office_admin'] == true,
    orElse: () => false,
  );
});

final subUsersProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return await api.getSubUsers();
});

enum SyncStatus { idle, syncing, success, error }

class SyncStatusState {
  final SyncStatus status;
  final String? errorMessage;
  final DateTime? lastSyncTime;

  SyncStatusState({
    required this.status,
    this.errorMessage,
    this.lastSyncTime,
  });

  SyncStatusState copyWith({
    SyncStatus? status,
    String? errorMessage,
    DateTime? lastSyncTime,
  }) {
    return SyncStatusState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
    );
  }
}

class SyncStatusNotifier extends Notifier<SyncStatusState> {
  @override
  SyncStatusState build() => SyncStatusState(status: SyncStatus.idle);

  void setSyncing() {
    state = state.copyWith(status: SyncStatus.syncing, errorMessage: null);
  }

  void setSuccess(DateTime time) {
    state = state.copyWith(status: SyncStatus.success, lastSyncTime: time);
  }

  void setError(String message) {
    state = state.copyWith(status: SyncStatus.error, errorMessage: message);
  }

  void setIdle() {
    state = state.copyWith(status: SyncStatus.idle);
  }
}

final syncStatusProvider = NotifierProvider<SyncStatusNotifier, SyncStatusState>(() {
  return SyncStatusNotifier();
});

final branchesProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return await api.getBranches();
});
