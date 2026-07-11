import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../providers.dart';
import '../../features/orders/providers/orders_provider.dart';

class SyncBadge extends ConsumerWidget {
  const SyncBadge({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingCountAsync = ref.watch(pendingSyncCountProvider);

    return pendingCountAsync.when(
      data: (count) => IconButton(
        icon: Badge(
          label: count > 0 ? Text('$count', style: const TextStyle(color: Colors.white, fontSize: 10)) : null,
          isLabelVisible: count > 0,
          backgroundColor: Colors.orange,
          child: Icon(
            count > 0 ? LucideIcons.cloudLightning : LucideIcons.cloud,
            color: count > 0 ? Colors.orange : Colors.green,
            size: 20,
          ),
        ),
        tooltip: count > 0 ? '$count unsynced orders' : 'All changes synced',
        onPressed: () {
          // Trigger manual background sync on tap!
          ref.read(syncRepositoryProvider).getOrders();
          ref.invalidate(ordersListProvider);
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Syncing changes with server...'),
              duration: Duration(seconds: 1),
            ),
          );
        },
      ),
      loading: () => const IconButton(
        icon: Icon(LucideIcons.cloud, color: Colors.grey, size: 20),
        onPressed: null,
      ),
      error: (err, _) => IconButton(
        icon: const Icon(LucideIcons.cloudOff, color: Colors.red, size: 20),
        tooltip: 'Sync Error',
        onPressed: () {
          ref.read(syncRepositoryProvider).getOrders();
          ref.invalidate(ordersListProvider);
        },
      ),
    );
  }
}
