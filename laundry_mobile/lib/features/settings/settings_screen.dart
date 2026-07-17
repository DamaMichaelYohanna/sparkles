import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'branch_management_screen.dart';
import 'office_details_screen.dart';
import 'services_pricing_screen.dart';
import 'staff_management_screen.dart';
import 'profile_screen.dart';
import '../auth/auth_screen.dart';
import '../../core/theme.dart';
import '../../core/providers.dart';
import '../../core/local_db/database_helper.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    // Reset user-specific cache providers
    ref.invalidate(userProfileProvider);
    ref.invalidate(branchesProvider);
    ref.invalidate(lastSyncTimestampProvider);
    ref.invalidate(syncStatusProvider);

    await DatabaseHelper.instance.clearDatabase();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(LucideIcons.user),
            title: const Text('My Profile'),
            subtitle: const Text('View and manage your account details'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
          const Divider(),
          if (isAdmin) ...[
            ListTile(
              leading: const Icon(LucideIcons.building),
              title: const Text('Office Details'),
              subtitle: const Text('Brand name, address, contact'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const OfficeDetailsScreen()),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(LucideIcons.gitBranch),
              title: const Text('Branches / Store Locations'),
              subtitle: const Text('Manage store locations and switch workspaces'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const BranchManagementScreen()),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(LucideIcons.tags),
              title: const Text('Services & Pricing'),
              subtitle: const Text('Manage laundry services and their prices'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ServicesPricingScreen()),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(LucideIcons.users),
              title: const Text('Staff Management'),
              subtitle: const Text('Manage staff accounts and assign roles'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const StaffManagementScreen()),
                );
              },
            ),
            const Divider(),
          ],
          ListTile(
            leading: const Icon(LucideIcons.logOut, color: Colors.redAccent),
            title: const Text('Logout', style: TextStyle(color: Colors.redAccent)),
            subtitle: const Text('Sign out of your session'),
            onTap: () => _logout(context, ref),
          ),
        ],
      ),
    );
  }
}
