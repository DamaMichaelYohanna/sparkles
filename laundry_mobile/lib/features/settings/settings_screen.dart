import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'office_details_screen.dart';
import 'services_pricing_screen.dart';
import 'staff_management_screen.dart';
import '../auth/auth_screen.dart';
import '../../core/theme.dart';
import '../../core/providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
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
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          if (!isAdmin)
            profileAsync.when(
              data: (profile) => Card(
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                            child: const Icon(LucideIcons.user, color: AppTheme.primaryColor),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${profile['first_name'] ?? ''} ${profile['last_name'] ?? ''}'.trim().isNotEmpty
                                      ? '${profile['first_name']} ${profile['last_name']}'
                                      : (profile['username'] ?? 'User'),
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  profile['email'] ?? 'No email associated',
                                  style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Text(
                        'Role: Staff / Operator',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Office: ${profile['office_name'] ?? 'My Laundry Office'}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
              loading: () => const Padding(
                padding: EdgeInsets.all(32.0),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Failed to load profile details: $e'),
              ),
            ),
          
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
            onTap: () => _logout(context),
          ),
        ],
      ),
    );
  }
}
