import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme.dart';
import '../../core/models/customer_model.dart';
import 'providers/customer_providers.dart';
import 'edit_customer_screen.dart';

class CustomersScreen extends ConsumerWidget {
  const CustomersScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customersState = ref.watch(filteredCustomersProvider);
    final searchController = TextEditingController(text: ref.read(customerSearchQueryProvider));

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Customers'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimary,
      ),
      body: Column(
        children: [
          // Search Box Container
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              controller: searchController,
              onChanged: (val) {
                ref.read(customerSearchQueryProvider.notifier).state = val;
              },
              decoration: InputDecoration(
                hintText: 'Search by name or phone...',
                prefixIcon: const Icon(LucideIcons.search, size: 20),
                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          searchController.clear();
                          ref.read(customerSearchQueryProvider.notifier).state = '';
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          
          // Customer List
          Expanded(
            child: customersState.when(
              data: (customers) {
                if (customers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.users, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          'No customers found',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          searchController.text.isEmpty
                              ? 'Tap the button below to add your first customer.'
                              : 'Try searching for something else.',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: customers.length,
                  itemBuilder: (context, index) {
                    final customer = customers[index];
                    return _CustomerCard(customer: customer);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(
                child: Text('Error loading customers: $err', style: const TextStyle(color: Colors.red)),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'add_customer_fab',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const EditCustomerScreen(),
            ),
          );
        },
        backgroundColor: AppTheme.textPrimary,
        child: const Icon(LucideIcons.userPlus, color: Colors.white),
      ),
    );
  }
}

class _CustomerCard extends ConsumerWidget {
  final CustomerModel customer;

  const _CustomerCard({Key? key, required this.customer}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Generate initials for avatar
    final initials = customer.name.isNotEmpty
        ? customer.name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase()
        : '?';

    // Premium subtle color matching
    final List<Color> colors = [
      const Color(0xFF6366F1), // Indigo
      const Color(0xFF3B82F6), // Blue
      const Color(0xFF8B5CF6), // Purple
      const Color(0xFFEC4899), // Pink
      const Color(0xFFF59E0B), // Amber
    ];
    final color = colors[customer.name.hashCode % colors.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withOpacity(0.8), color],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            initials,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        title: Text(
          customer.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(LucideIcons.phone, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 6),
                Text(
                  customer.phone.isNotEmpty ? customer.phone : 'No Phone Number',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
            if (customer.isWhatsapp) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(LucideIcons.messageCircle, size: 14, color: Color(0xFF25D366)),
                  const SizedBox(width: 6),
                  Text(
                    'WhatsApp Enabled',
                    style: TextStyle(color: Colors.green[600], fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ],
        ),
        trailing: Container(
          decoration: BoxDecoration(
            color: Colors.grey[100],
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(LucideIcons.edit2, size: 16, color: Colors.blueGrey),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditCustomerScreen(customer: customer),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
