import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'branch_management_screen.dart';
import 'office_details_screen.dart';
import 'services_pricing_screen.dart';
import 'staff_management_screen.dart';
import '../auth/auth_screen.dart';
import '../../core/theme.dart';
import '../../core/providers.dart';
import '../../core/local_db/database_helper.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isCheckingStatus = false;

  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('last_sync_timestamp');

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

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  void _verifyPayment(String reference, StateSetter setDialogState) async {
    setDialogState(() => _isCheckingStatus = true);
    setState(() => _isCheckingStatus = true);
    print('[Billing] Verifying transaction reference: $reference');
    try {
      final api = ref.read(apiServiceProvider);
      final res = await api.verifySubscription(reference);
      print('[Billing] Verification response received: $res');
      
      if (mounted) {
        setDialogState(() => _isCheckingStatus = false);
        setState(() => _isCheckingStatus = false);
        // Clear checking dialog/state and refresh profile
        ref.refresh(userProfileProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Subscription upgraded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(); // Close check status dialog
      }
    } catch (e) {
      print('[Billing] Verification failed/pending: $e');
      if (mounted) {
        setDialogState(() => _isCheckingStatus = false);
        setState(() => _isCheckingStatus = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification pending: ${e.toString().replaceAll('Exception:', '').trim()}'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _showVerifyDialog(String reference) {
    print('[Billing] Displaying verify dialog for reference: $reference');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Complete Payment'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('We have opened the Paystack checkout page in your browser.'),
                  const SizedBox(height: 12),
                  const Text('Please complete the billing transaction and return here to verify.'),
                  if (_isCheckingStatus) ...[
                    const SizedBox(height: 20),
                    const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: _isCheckingStatus
                      ? null
                      : () {
                          print('[Billing] Closed verification status dialog manually.');
                          Navigator.of(context).pop();
                        },
                  child: const Text('Close'),
                ),
                ElevatedButton(
                  onPressed: _isCheckingStatus
                      ? null
                      : () {
                          _verifyPayment(reference, setDialogState);
                        },
                  child: const Text('Verify Payment'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSubscriptionSheet(String currentTier) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final plans = [
          {
            'id': 'free',
            'name': 'Free Tier',
            'price': '₦0',
            'period': '/ month',
            'desc': 'Limited free plan to get started.',
            'features': ['Point of Sale & Billing', 'Up to 50 orders/month', '1 Store Location', 'Max 1 Staff Account'],
          },
          {
            'id': 'starter',
            'name': 'Starter Tier',
            'price': '₦2,500',
            'period': '/ month',
            'desc': 'Support for standard small operations.',
            'features': ['Point of Sale & Billing', 'Up to 500 orders/month', '1 Store Location', 'Basic Sales Reports', 'Up to 3 Staff Accounts', 'Email & SMS Receipts'],
          },
          {
            'id': 'pro',
            'name': 'Pro Tier',
            'price': '₦7,500',
            'period': '/ month',
            'desc': 'Grow your multi-location laundry business.',
            'features': ['Unlimited Orders', 'Up to 3 Store Locations', 'Up to 10 Staff Accounts', 'Inventory & Expense Tracking', 'WhatsApp Notifications', 'Rider & Delivery Management'],
          },
          {
            'id': 'premium',
            'name': 'Premium Tier',
            'price': '₦15,000',
            'period': '/ month',
            'desc': 'Full operational suite and scaling tools.',
            'features': ['Unlimited Store Locations', 'Unlimited Staff Accounts', 'Automated Marketing Campaigns', 'Loyalty & Subscriptions', 'Advanced Analytics & P/L', 'Priority 24/7 Support'],
          },
        ];

        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Select Subscription Plan',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Upgrade your billing plan to increase orders, staff slots, and unlock premium tools.',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: plans.length,
                      itemBuilder: (context, index) {
                        final plan = plans[index];
                        final isCurrent = currentTier.toLowerCase() == plan['id'];
                        final isFree = plan['id'] == 'free';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: isCurrent ? AppTheme.primaryColor : Colors.grey.shade200,
                              width: isCurrent ? 2 : 1,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      plan['name'] as String,
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                                    if (isCurrent)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Text(
                                          'Current',
                                          style: TextStyle(
                                            color: AppTheme.primaryColor,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  plan['desc'] as String,
                                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      plan['price'] as String,
                                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                                    ),
                                    Text(
                                      plan['period'] as String,
                                      style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                                    ),
                                    if (!isFree)
                                      const SizedBox(width: 8),
                                    if (!isFree)
                                      Text(
                                        '50% OFF',
                                        style: TextStyle(
                                          color: Colors.green[700],
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                  ],
                                ),
                                const Divider(height: 24),
                                Column(
                                  children: (plan['features'] as List<String>).map((feat) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.check_circle, size: 16, color: Colors.green),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              feat,
                                              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isCurrent ? Colors.grey[200] : AppTheme.primaryColor,
                                      foregroundColor: isCurrent ? Colors.grey[600] : Colors.white,
                                    ),
                                    onPressed: isCurrent
                                        ? null
                                        : () async {
                                            Navigator.of(sheetContext).pop(); // Close sheet
                                            
                                            // Handle free subscription tier directly or call upgrade initialize
                                            if (isFree) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Free Tier can be downgraded via admin support.')),
                                              );
                                              return;
                                            }

                                            print('[Billing] Initializing payment loader for tier: ${plan['id']}');
                                            bool loaderShowed = true;
                                            showDialog(
                                              context: context, // Screen context
                                              barrierDismissible: false,
                                              builder: (dialogContext) => const Center(child: CircularProgressIndicator()),
                                            ).then((_) {
                                              loaderShowed = false;
                                            });

                                            try {
                                              final api = ref.read(apiServiceProvider);
                                              print('[Billing] Triggering backend billing initialization...');
                                              final res = await api.initializeSubscription(plan['id'] as String);
                                              print('[Billing] Billing successfully initialized: $res');
                                              
                                              if (mounted) {
                                                if (loaderShowed) {
                                                  Navigator.of(context).pop(); // Close loading dialog
                                                  loaderShowed = false;
                                                }
                                                
                                                final url = res['authorization_url'];
                                                final refStr = res['reference'];
                                                
                                                print('[Billing] Opening Paystack checkout URL: $url');
                                                await _launchUrl(url);
                                                _showVerifyDialog(refStr);
                                              }
                                            } catch (e) {
                                              print('[Billing] Failed to initialize subscription: $e');
                                              if (mounted) {
                                                if (loaderShowed) {
                                                  Navigator.of(context).pop(); // Close loading dialog
                                                  loaderShowed = false;
                                                }
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text('Failed to initialize upgrade: ${e.toString().replaceAll('Exception:', '').trim()}'),
                                                    backgroundColor: Colors.red,
                                                  ),
                                                );
                                              }
                                            }
                                          },
                                    child: Text(isCurrent ? 'Current Plan' : 'Upgrade to ${plan['name']}'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider);
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: profileAsync.when(
        data: (profile) {
          final tier = profile['subscription_tier'] ?? 'free';
          final tierName = tier.toString().toUpperCase();

          return ListView(
            children: [
              Card(
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
                        isAdmin ? 'Role: Administrator' : 'Role: Staff / Operator',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isAdmin ? AppTheme.primaryColor : Colors.orange.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Office: ${profile['office_name'] ?? 'My Laundry Office'}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'SUBSCRIPTION PLAN',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                tierName,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: tier.toString().toLowerCase() == 'free' ? Colors.grey[700] : Colors.green[700],
                                ),
                              ),
                            ],
                          ),
                          if (isAdmin)
                            OutlinedButton.icon(
                              onPressed: () => _showSubscriptionSheet(tier),
                              icon: const Icon(Icons.payment, size: 16),
                              label: const Text('Manage Plan'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
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
                onTap: () => _logout(context),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Failed to load profile details: $e'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(userProfileProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
