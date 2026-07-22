import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../dashboard/dashboard_screen.dart';
import '../orders/orders_screen.dart';
import '../analysis/analysis_screen.dart';
import '../settings/settings_screen.dart';
import '../../core/theme.dart';
import '../../core/providers.dart';

class ShellScreen extends ConsumerStatefulWidget {
  const ShellScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends ConsumerState<ShellScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider);

    final List<Widget> screens = [
      const DashboardScreen(),
      const OrdersScreen(),
      if (isAdmin) const AnalysisScreen(),
      const SettingsScreen(),
    ];

    // Align current index in case screens list size changes dynamically
    final actualIndex = _currentIndex >= screens.length ? 0 : _currentIndex;

    return Scaffold(
      body: IndexedStack(
        index: actualIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: actualIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: Colors.white,
          selectedItemColor: AppTheme.textPrimary,
          unselectedItemColor: AppTheme.textSecondary.withOpacity(0.4),
          showSelectedLabels: true,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(LucideIcons.layoutDashboard),
              label: 'Dashboard',
            ),
            const BottomNavigationBarItem(
              icon: Icon(LucideIcons.shoppingBag),
              label: 'Orders',
            ),
            if (isAdmin)
              const BottomNavigationBarItem(
                icon: Icon(LucideIcons.barChart2),
                label: 'Analysis',
              ),
            const BottomNavigationBarItem(
              icon: Icon(LucideIcons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
      floatingActionButton: actualIndex == 1
          ? null
          : FloatingActionButton(
              onPressed: _launchWhatsApp,
              backgroundColor: const Color(0xFF25D366),
              tooltip: 'Contact Us on WhatsApp',
              child: const Icon(LucideIcons.messageCircle, color: Colors.white),
            ),
    );
  }

  Future<void> _launchWhatsApp() async {
    final Uri url = Uri.parse('https://wa.me/2348160535033');
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch WhatsApp');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open WhatsApp: $e')),
        );
      }
    }
  }
}
