import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../providers.dart';
import '../../features/orders/providers/orders_provider.dart';

class SyncBadge extends ConsumerStatefulWidget {
  const SyncBadge({Key? key}) : super(key: key);

  @override
  ConsumerState<SyncBadge> createState() => _SyncBadgeState();
}

class _SyncBadgeState extends ConsumerState<SyncBadge> with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pendingCountAsync = ref.watch(pendingSyncCountProvider);
    final syncState = ref.watch(syncStatusProvider);

    // Reactively trigger/stop animation based on sync state
    if (syncState.status == SyncStatus.syncing) {
      _rotationController.repeat();
    } else {
      _rotationController.stop();
    }

    // Listen to status changes to trigger snackbars
    ref.listen<SyncStatusState>(syncStatusProvider, (previous, next) {
      if (next.status == SyncStatus.syncing) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Syncing changes with server...'),
            duration: Duration(seconds: 1),
          ),
        );
      } else if (next.status == SyncStatus.success) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sync complete! All changes saved.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        // Reset back to idle after a delay to clear checkmark state
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted && ref.read(syncStatusProvider).status == SyncStatus.success) {
            ref.read(syncStatusProvider.notifier).setIdle();
          }
        });
      } else if (next.status == SyncStatus.error) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: ${next.errorMessage}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });

    return pendingCountAsync.when(
      data: (count) {
        Widget icon;
        Color iconColor;
        String tooltip;

        switch (syncState.status) {
          case SyncStatus.syncing:
            icon = RotationTransition(
              turns: _rotationController,
              child: const Icon(LucideIcons.refreshCw, size: 20),
            );
            iconColor = Colors.blue;
            tooltip = 'Syncing...';
            break;
          case SyncStatus.success:
            icon = const Icon(LucideIcons.checkCircle, size: 20);
            iconColor = Colors.green;
            tooltip = 'Sync successful';
            break;
          case SyncStatus.error:
            icon = const Icon(LucideIcons.cloudOff, size: 20);
            iconColor = Colors.red;
            tooltip = 'Sync Error: ${syncState.errorMessage}';
            break;
          case SyncStatus.idle:
          default:
            icon = Icon(
              count > 0 ? LucideIcons.cloudLightning : LucideIcons.cloud,
              size: 20,
            );
            iconColor = count > 0 ? Colors.orange : Colors.green;
            tooltip = count > 0 ? '$count unsynced orders' : 'All changes synced';
            break;
        }

        return IconButton(
          icon: Badge(
            label: count > 0 && syncState.status != SyncStatus.syncing
                ? Text('$count', style: const TextStyle(color: Colors.white, fontSize: 10))
                : null,
            isLabelVisible: count > 0 && syncState.status != SyncStatus.syncing,
            backgroundColor: Colors.orange,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              child: icon,
            ),
          ),
          color: iconColor,
          tooltip: tooltip,
          onPressed: syncState.status == SyncStatus.syncing
              ? null
              : () {
                  ref.read(syncRepositoryProvider).triggerSync();
                  ref.invalidate(ordersListProvider);
                },
        );
      },
      loading: () => const IconButton(
        icon: Icon(LucideIcons.cloud, color: Colors.grey, size: 20),
        onPressed: null,
      ),
      error: (err, _) => IconButton(
        icon: const Icon(LucideIcons.cloudOff, color: Colors.red, size: 20),
        tooltip: 'Sync Error: $err',
        onPressed: () {
          ref.read(syncRepositoryProvider).triggerSync();
          ref.invalidate(ordersListProvider);
        },
      ),
    );
  }
}
