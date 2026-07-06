import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'network/api_service.dart';
import 'repositories/sync_repository.dart';

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService();
});

final syncRepositoryProvider = Provider<SyncRepository>((ref) {
  return SyncRepository();
});
