import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme.dart';
import 'providers/add_order_provider.dart';

class AddOrderScreen extends ConsumerStatefulWidget {
  const AddOrderScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<AddOrderScreen> createState() => _AddOrderScreenState();
}

class _AddOrderScreenState extends ConsumerState<AddOrderScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _showItemSelectionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          builder: (_, controller) {
            return Consumer(
              builder: (context, ref, child) {
                final pricingAsync = ref.watch(itemPricingListProvider);
                return pricingAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Center(child: Text('Error: $error')),
                  data: (pricings) {
                    if (pricings.isEmpty) {
                      return const Center(child: Text("No items available. Please sync first."));
                    }
                    return Column(
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            'Select Service Item',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            controller: controller,
                            itemCount: pricings.length,
                            itemBuilder: (context, index) {
                              final pricing = pricings[index];
                              return ListTile(
                                title: Text('Item ID: ${pricing.id}'), // Ideal: show category/service name via join, but this is a simplified MVP
                                subtitle: Text('₦${pricing.price}'),
                                trailing: IconButton(
                                  icon: const Icon(LucideIcons.plusCircle, color: AppTheme.primaryColor),
                                  onPressed: () {
                                    ref.read(addOrderProvider.notifier).addItem(pricing, 1);
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Item added to cart!'), duration: Duration(seconds: 1)),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  }
                );
              }
            );
          },
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final draftState = ref.watch(addOrderProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Order'),
        leading: IconButton(
          icon: const Icon(LucideIcons.x),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Customer Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(LucideIcons.user),
              ),
              onChanged: (val) => ref.read(addOrderProvider.notifier).updateCustomerInfo(name: val, phone: _phoneController.text),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number (Optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(LucideIcons.phone),
              ),
              keyboardType: TextInputType.phone,
              onChanged: (val) => ref.read(addOrderProvider.notifier).updateCustomerInfo(name: _nameController.text, phone: val),
            ),
            const SizedBox(height: 32),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Order Items', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                TextButton.icon(
                  onPressed: () => _showItemSelectionSheet(context),
                  icon: const Icon(LucideIcons.plus),
                  label: const Text('Add Item'),
                )
              ],
            ),
            const SizedBox(height: 16),
            
            if (draftState.items.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                ),
                child: const Column(
                  children: [
                    Icon(LucideIcons.shoppingCart, size: 48, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('No items added yet', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: draftState.items.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final item = draftState.items[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Pricing ID: ${item.itemPricingId.substring(0, 8)}...'),
                    subtitle: Text('Qty: ${item.quantity} x ₦${item.unitPrice}'),
                    trailing: Text('₦${item.subtotal}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  );
                },
              ),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16).copyWith(bottom: MediaQuery.of(context).padding.bottom + 16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            )
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Amount', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  Text('₦${draftState.total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppTheme.primaryColor)),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: draftState.items.isEmpty || draftState.customerName.isEmpty
                  ? null
                  : () async {
                      try {
                        await ref.read(addOrderProvider.notifier).saveOrder();
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Order saved locally (Pending Sync)')),
                          );
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Save Order', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
