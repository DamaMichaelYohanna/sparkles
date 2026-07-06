import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'office_details_screen.dart';
import 'services_pricing_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
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
        ],
      ),
    );
  }
}
