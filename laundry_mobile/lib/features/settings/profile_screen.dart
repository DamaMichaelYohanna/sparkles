import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme.dart';
import '../../core/providers.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isCheckingStatus = false;

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  void _verifyPayment([String? reference, StateSetter? setDialogState]) async {
    final navigator = Navigator.of(context);
    if (setDialogState != null) setDialogState(() => _isCheckingStatus = true);
    setState(() => _isCheckingStatus = true);
    try {
      final api = ref.read(apiServiceProvider);
      final res = await api.verifySubscription(reference);
      
      if (mounted) {
        if (setDialogState != null) setDialogState(() => _isCheckingStatus = false);
        setState(() => _isCheckingStatus = false);
        ref.refresh(userProfileProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Subscription upgraded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        if (navigator.canPop()) navigator.pop();
      }
    } catch (e) {
      if (mounted) {
        if (setDialogState != null) setDialogState(() => _isCheckingStatus = false);
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

  void _showVerifyDialog([String? reference, String? authUrl]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(LucideIcons.shieldCheck, color: AppTheme.primaryColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text('Payment Verification', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Complete your billing checkout in the browser and tap "Verify Payment" below to activate your plan.',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
                  ),
                  if (authUrl != null && authUrl.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => _launchUrl(authUrl),
                      icon: const Icon(LucideIcons.externalLink, size: 14),
                      label: const Text('Re-open Checkout Page'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
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
                          Navigator.of(context).pop();
                        },
                  child: const Text('Close'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  icon: const Icon(LucideIcons.checkCircle2, size: 16),
                  onPressed: _isCheckingStatus
                      ? null
                      : () {
                          _verifyPayment(reference, setDialogState);
                        },
                  label: const Text('Verify Payment'),
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
                                            
                                            if (isFree) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Free Tier can be downgraded via admin support.')),
                                              );
                                              return;
                                            }
                                            
                                            final navigator = Navigator.of(context);
                                            bool loaderShowed = true;
                                            showDialog(
                                              context: context,
                                              barrierDismissible: false,
                                              builder: (dialogContext) => const Center(child: CircularProgressIndicator()),
                                            ).then((_) {
                                              loaderShowed = false;
                                            });

                                            try {
                                              final api = ref.read(apiServiceProvider);
                                              final res = await api.initializeSubscription(plan['id'] as String);
                                              
                                              if (mounted) {
                                                if (loaderShowed) {
                                                  navigator.pop();
                                                  loaderShowed = false;
                                                }
                                                
                                                final url = res['authorization_url'];
                                                final refStr = res['reference'];
                                                
                                                await _launchUrl(url);
                                                _showVerifyDialog(refStr, url);
                                              }
                                            } catch (e) {
                                              if (mounted) {
                                                if (loaderShowed) {
                                                  navigator.pop();
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
        title: const Text('My Profile'),
      ),
      body: profileAsync.when(
        data: (profile) {
          final tier = profile['subscription_tier'] ?? 'free';
          final tierName = tier.toString().toUpperCase();

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                      child: Text(
                        '${profile['first_name'] ?? ''} ${profile['last_name'] ?? ''}'.trim().isNotEmpty
                            ? '${profile['first_name'][0]}${profile['last_name'][0]}'.toUpperCase()
                            : (profile['username'] ?? 'U')[0].toUpperCase(),
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${profile['first_name'] ?? ''} ${profile['last_name'] ?? ''}'.trim().isNotEmpty
                          ? '${profile['first_name']} ${profile['last_name']}'
                          : (profile['username'] ?? 'User'),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      profile['email'] ?? 'No email associated',
                      style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              // Role & Workspace Info Card
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade100),
                ),
                elevation: 0,
                child: Column(
                  children: [
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(LucideIcons.shield, color: Colors.blue.shade700, size: 20),
                      ),
                      title: const Text('Role', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      subtitle: Text(
                        isAdmin ? 'Administrator' : 'Staff / Operator',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(LucideIcons.building, color: Colors.amber.shade700, size: 20),
                      ),
                      title: const Text('Office / Workspace', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      subtitle: Text(
                        profile['office_name'] ?? 'My Laundry Office',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Plan Card
              Builder(
                builder: (context) {
                  final pendingSub = profile['office_preferences']?['pending_subscription'] as Map<String, dynamic>?;
                  final pendingTier = pendingSub?['tier']?.toString().toUpperCase();
                  final pendingRef = pendingSub?['reference']?.toString();
                  final pendingUrl = pendingSub?['authorization_url']?.toString();

                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.shade100),
                    ),
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                                  const SizedBox(height: 4),
                                  Text(
                                    tierName,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: tier.toString().toLowerCase() == 'free' ? Colors.grey[700] : Colors.green[700],
                                    ),
                                  ),
                                ],
                              ),
                              if (isAdmin)
                                Row(
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: () => _showVerifyDialog(pendingRef, pendingUrl),
                                      icon: const Icon(LucideIcons.shieldCheck, size: 14),
                                      label: const Text('Verify'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppTheme.primaryColor,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton.icon(
                                      onPressed: () => _showSubscriptionSheet(tier),
                                      icon: const Icon(Icons.payment, size: 14),
                                      label: const Text('Manage Plan'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primaryColor,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                          if (pendingSub != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.amber.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(LucideIcons.alertCircle, color: Colors.amber.shade800, size: 18),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Pending Upgrade: $pendingTier',
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                                        ),
                                        const Text(
                                          'Payment initialized. Tap "Verify Now" after completing Paystack checkout.',
                                          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => _showVerifyDialog(pendingRef, pendingUrl),
                                    child: const Text('Verify Now', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
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
