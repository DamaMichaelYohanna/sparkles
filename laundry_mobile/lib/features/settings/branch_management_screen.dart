import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme.dart';
import '../../core/providers.dart';
import '../../core/local_db/database_helper.dart';
import '../orders/providers/orders_provider.dart';
import '../dashboard/providers/dashboard_provider.dart';
import '../analysis/providers/analysis_provider.dart';

class BranchManagementScreen extends ConsumerWidget {
  const BranchManagementScreen({Key? key}) : super(key: key);

  int? _getBranchLimit(String tier) {
    final t = tier.toLowerCase();
    if (t == 'free') return 1;
    if (t == 'starter') return 1;
    if (t == 'pro') return 3;
    return null; // Unlimited for Premium
  }

  void _showUpgradeLimitDialog(BuildContext context, String tier, int limit) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.lock_outline, color: Colors.orange.shade700, size: 28),
              const SizedBox(width: 12),
              const Text('Upgrade Workspace'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Branch limit reached for ${tier.toUpperCase()} Tier.',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 12),
              Text(
                'Your current plan allows a maximum of $limit store location(s).\n\nUpgrade your workspace subscription plan to add multiple branch locations and sync them seamlessly.',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Click 'Manage Plan' at the top of the settings page to upgrade."),
                  ),
                );
              },
              child: const Text('Upgrade Subscription'),
            ),
          ],
        );
      },
    );
  }

  void _showAddBranchDialog(BuildContext context, WidgetRef ref, int currentCount, String tier) {
    final limit = _getBranchLimit(tier);
    if (limit != null && currentCount >= limit) {
      _showUpgradeLimitDialog(context, tier, limit);
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        final formKey = GlobalKey<FormState>();
        final nameController = TextEditingController();
        final contactController = TextEditingController();
        bool isSubmitting = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Add New Branch'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Branch Name',
                        hintText: 'e.g., Ikeja Branch',
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Branch name is required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: contactController,
                      decoration: const InputDecoration(
                        labelText: 'Contact Info / Address',
                        hintText: 'e.g., 12 Allen Ave, Ikeja',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (isSubmitting) ...[
                      const SizedBox(height: 16),
                      const CircularProgressIndicator(),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => isSubmitting = true);
                          try {
                            final api = ref.read(apiServiceProvider);
                            await api.createBranch(
                              nameController.text.trim(),
                              contactController.text.trim(),
                            );

                            // Clear local database and reset synchronization state for full sync
                            await DatabaseHelper.instance.clearDatabase();
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.remove('last_sync_timestamp');

                            ref.invalidate(userProfileProvider);
                            ref.invalidate(branchesProvider);
                            ref.invalidate(ordersListProvider);
                            ref.invalidate(recentOrdersProvider);
                            ref.invalidate(dashboardStatsProvider);
                            ref.invalidate(rawAnalysisOrdersProvider);

                            ref.read(syncRepositoryProvider).triggerSync();

                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Branch created and set as active workspace.')),
                              );
                            }
                          } catch (e) {
                            setDialogState(() => isSubmitting = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(e.toString().replaceAll('Exception:', '').trim()),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _switchWorkspace(BuildContext context, WidgetRef ref, Map<String, dynamic> branch) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Switch Branch'),
        content: Text('Switch active workspace to "${branch['name']}"? This will refresh all your orders and settings.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Switch'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      try {
        final api = ref.read(apiServiceProvider);
        await api.switchBranch(branch['id']);

        // Clear offline state & reset sync timestamp
        await DatabaseHelper.instance.clearDatabase();
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('last_sync_timestamp');

        // Invalidate providers
        ref.invalidate(userProfileProvider);
        ref.invalidate(branchesProvider);
        ref.invalidate(ordersListProvider);
        ref.invalidate(recentOrdersProvider);
        ref.invalidate(dashboardStatsProvider);
        ref.invalidate(rawAnalysisOrdersProvider);

        // Run full sync for new store branch
        ref.read(syncRepositoryProvider).triggerSync();

        if (context.mounted) {
          Navigator.pop(context); // Pop loading indicator
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Switched to "${branch['name']}"')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          Navigator.pop(context); // Pop loading indicator
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceAll('Exception:', '').trim()),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchesAsync = ref.watch(branchesProvider);
    final profileAsync = ref.watch(userProfileProvider);
    final isAdmin = ref.watch(isAdminProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Branches / Store Locations'),
      ),
      body: profileAsync.when(
        data: (profile) {
          return branchesAsync.when(
            data: (branches) {
              return ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  Card(
                    color: AppTheme.primaryColor.withOpacity(0.05),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: AppTheme.primaryColor.withOpacity(0.15)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Icon(LucideIcons.info, color: Colors.grey[700], size: 20),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Manage multiple store locations. Tap on any branch to switch your active workspace.',
                              style: TextStyle(fontSize: 13, height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...branches.map((b) {
                    final branch = b as Map<String, dynamic>;
                    final isActive = branch['is_active'] == true;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: isActive 
                            ? const BorderSide(color: AppTheme.primaryColor, width: 1.5) 
                            : BorderSide(color: Colors.grey.shade200),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isActive 
                              ? AppTheme.primaryColor.withOpacity(0.1) 
                              : Colors.grey.shade100,
                          child: Icon(
                            LucideIcons.building, 
                            color: isActive ? AppTheme.primaryColor : Colors.grey,
                          ),
                        ),
                        title: Text(
                          branch['name'] ?? 'Branch Office',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          branch['contact_info']?.toString().isNotEmpty == true
                              ? branch['contact_info']
                              : 'No contact info added',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: isActive
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Active',
                                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              )
                            : const Icon(Icons.swap_horiz, color: Colors.grey),
                        onTap: isActive ? null : () => _switchWorkspace(context, ref, branch),
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: 80), // spacer for FAB
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text('Failed to load branches: $e'),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Failed to load profile: $e'),
        ),
      ),
      floatingActionButton: profileAsync.maybeWhen(
        data: (profile) {
          final tier = profile['subscription_tier'] ?? 'free';
          final branchesCount = branchesAsync.value?.length ?? 0;
          
          return isAdmin
              ? FloatingActionButton.extended(
                  onPressed: () => _showAddBranchDialog(
                    context, 
                    ref, 
                    branchesCount, 
                    tier,
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Branch'),
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                )
              : null;
        },
        orElse: () => null,
      ),
    );
  }
}
