import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme.dart';
import '../../core/local_db/database_helper.dart';
import 'providers/add_order_provider.dart';
import '../settings/providers/pricing_provider.dart';
import '../../core/models/category_model.dart';
import '../../core/models/service_type_model.dart';
import '../../core/models/item_pricing_model.dart';

class AddOrderScreen extends ConsumerStatefulWidget {
  const AddOrderScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<AddOrderScreen> createState() => _AddOrderScreenState();
}

class _AddOrderScreenState extends ConsumerState<AddOrderScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _amountPaidController;
  bool _isFullyPaidChecked = false;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(addOrderProvider);
    _nameController = TextEditingController(text: draft.customerName);
    _phoneController = TextEditingController(text: draft.customerPhone);
    
    final total = draft.total;
    final amountPaid = draft.amountPaid;
    _isFullyPaidChecked = amountPaid >= total && total > 0;
    
    _amountPaidController = TextEditingController(
      text: _isFullyPaidChecked ? total.toStringAsFixed(2) : amountPaid.toStringAsFixed(2)
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _amountPaidController.dispose();
    super.dispose();
  }

  void _showCustomerSelectionSheet(BuildContext context) async {
    final customers = await DatabaseHelper.instance.getUniqueCustomers();
    if (!context.mounted) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return _CustomerSelectionSheet(
          customers: customers,
          onSelected: (customer) {
            _nameController.text = customer['name']!;
            _phoneController.text = customer['phone']!;
            ref.read(addOrderProvider.notifier).updateCustomerInfo(
              name: customer['name']!,
              phone: customer['phone']!,
              customerId: customer['id']!,
            );
          },
        );
      },
    );
  }

  void _showItemSelectionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return const _ItemSelectionSheet();
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final draftState = ref.watch(addOrderProvider);
    final pricingListAsync = ref.watch(itemPricingListProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final servicesAsync = ref.watch(serviceTypesProvider);

    if (_isFullyPaidChecked) {
      final totalStr = draftState.total.toStringAsFixed(2);
      if (_amountPaidController.text != totalStr || draftState.amountPaid != draftState.total) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _amountPaidController.text = totalStr;
            ref.read(addOrderProvider.notifier).updateAmountPaid(draftState.total);
          }
        });
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(draftState.existingOrderId != null ? 'Edit Order' : 'Create New Order'),
        leading: IconButton(
          icon: const Icon(LucideIcons.x),
          onPressed: () {
            ref.read(addOrderProvider.notifier).resetState();
            Navigator.pop(context);
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Customer Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                TextButton.icon(
                  onPressed: () => _showCustomerSelectionSheet(context),
                  icon: const Icon(LucideIcons.users, size: 16),
                  label: const Text('Returning Customer'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(LucideIcons.user),
              ),
              onChanged: (val) => ref.read(addOrderProvider.notifier).updateCustomerInfo(name: val, phone: _phoneController.text, clearCustomerId: true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Whatsapp Number (Essential)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(LucideIcons.phone),
                counterText: '',
              ),
              keyboardType: TextInputType.phone,
              maxLength: 11,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              onChanged: (val) => ref.read(addOrderProvider.notifier).updateCustomerInfo(name: _nameController.text, phone: val, clearCustomerId: true),
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
                  String displayName = 'Laundry Item';
                  
                  if (pricingListAsync.hasValue && categoriesAsync.hasValue && servicesAsync.hasValue) {
                    final pricings = pricingListAsync.value ?? [];
                    final categories = categoriesAsync.value ?? [];
                    final services = servicesAsync.value ?? [];
                    
                    try {
                      final pricing = pricings.firstWhere((p) => p.id == item.itemPricingId);
                      final cat = categories.firstWhere((c) => c.id == pricing.categoryId);
                      final svc = services.firstWhere((s) => s.id == pricing.serviceTypeId);
                      displayName = "${cat.name} (${svc.name})";
                    } catch (_) {}
                  }

                  return Dismissible(
                    key: Key(item.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      color: Colors.redAccent,
                      child: const Icon(LucideIcons.trash2, color: Colors.white),
                    ),
                    onDismissed: (direction) {
                      ref.read(addOrderProvider.notifier).removeItem(index);
                    },
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(displayName),
                      subtitle: Text(
                        'Qty: ${item.quantity} x ₦${item.unitPrice}' +
                        (item.discountAmount > 0
                            ? ' (Discount: -₦${item.discountAmount.toStringAsFixed(0)})'
                            : ''),
                      ),
                      trailing: Text('₦${item.subtotal}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  );
                },
              ),
            
            const SizedBox(height: 24),
            const Text('Order Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Overall Order Discount (₦) - Optional',
                border: OutlineInputBorder(),
                prefixIcon: Icon(LucideIcons.tag),
              ),
              keyboardType: TextInputType.number,
              onChanged: (val) {
                final discount = double.tryParse(val) ?? 0.0;
                ref.read(addOrderProvider.notifier).updateOrderDiscount(discount);
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _amountPaidController,
                    decoration: const InputDecoration(
                      labelText: 'Amount Paid (₦)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(LucideIcons.wallet),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    enabled: !_isFullyPaidChecked,
                    onChanged: (val) {
                      final amount = double.tryParse(val) ?? 0.0;
                      ref.read(addOrderProvider.notifier).updateAmountPaid(amount);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Row(
                  children: [
                    Checkbox(
                      value: _isFullyPaidChecked,
                      onChanged: (val) {
                        setState(() {
                          _isFullyPaidChecked = val ?? false;
                          if (_isFullyPaidChecked) {
                            ref.read(addOrderProvider.notifier).updateAmountPaid(draftState.total);
                            _amountPaidController.text = draftState.total.toStringAsFixed(2);
                          }
                        });
                      },
                      activeColor: AppTheme.primaryColor,
                    ),
                    const Text('Fully Paid', style: TextStyle(fontWeight: FontWeight.w500)),
                  ],
                ),
              ],
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
                  if (draftState.orderDiscount > 0) ...[
                    Text(
                      'Subtotal: ₦${draftState.items.fold(0.0, (sum, item) => sum + item.subtotal).toStringAsFixed(2)}',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                    ),
                    Text(
                      'Discount: -₦${draftState.orderDiscount.toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                  ],
                  const Text('Total Amount', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  Text('₦${draftState.total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppTheme.primaryColor)),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: draftState.items.isEmpty || draftState.customerName.isEmpty
                  ? null
                  : () async {
                      if (draftState.customerPhone.isNotEmpty && draftState.customerPhone.length != 11) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Nigerian phone numbers must be exactly 11 digits.'),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                        return;
                      }
                      try {
                        final isEditing = draftState.existingOrderId != null;
                        await ref.read(addOrderProvider.notifier).saveOrder();
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(isEditing ? 'Order updated successfully' : 'Order saved locally (Pending Sync)')),
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
              child: Text(draftState.existingOrderId != null ? 'Update Order' : 'Save Order', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemSelectionSheet extends ConsumerStatefulWidget {
  const _ItemSelectionSheet({Key? key}) : super(key: key);

  @override
  ConsumerState<_ItemSelectionSheet> createState() => _ItemSelectionSheetState();
}

class _ItemSelectionSheetState extends ConsumerState<_ItemSelectionSheet> {
  String? selectedCategoryId;
  String? selectedServiceId;
  int quantity = 1;
  final _discountController = TextEditingController();

  @override
  void dispose() {
    _discountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final servicesAsync = ref.watch(serviceTypesProvider);
    final pricingAsync = ref.watch(itemPricingProvider);

    if (categoriesAsync.isLoading || servicesAsync.isLoading || pricingAsync.isLoading) {
      return const SizedBox(
        height: 300,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final categories = categoriesAsync.value ?? [];
    final services = servicesAsync.value ?? [];
    final pricings = pricingAsync.value ?? [];

    if (categories.isEmpty || services.isEmpty) {
      return const SizedBox(
        height: 300,
        child: Center(child: Text("No Categories or Services configured yet.")),
      );
    }

    // Determine currently selected pricing rule (if any)
    ItemPricingModel? activePricing;
    if (selectedCategoryId != null && selectedServiceId != null) {
      try {
        activePricing = pricings.firstWhere(
          (p) => p.categoryId == selectedCategoryId && p.serviceTypeId == selectedServiceId,
        );
      } catch (e) {
        activePricing = null; // No rule matching this combo
      }
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Add Item to Order',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'Fabric Category (e.g. T-Shirt)'),
            value: selectedCategoryId,
            items: categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
            onChanged: (val) => setState(() => selectedCategoryId = val),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'Service Type (e.g. Washing & Ironing)'),
            value: selectedServiceId,
            items: services.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
            onChanged: (val) => setState(() => selectedServiceId = val),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _discountController,
            decoration: const InputDecoration(
              labelText: 'Item Discount (₦) - Optional',
              border: OutlineInputBorder(),
              prefixIcon: Icon(LucideIcons.tag),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 24),
          
          if (selectedCategoryId != null && selectedServiceId != null)
            if (activePricing != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Unit Price:', style: TextStyle(fontSize: 16)),
                        Text('₦${activePricing.price}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Quantity:', style: TextStyle(fontSize: 16)),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: quantity > 1 ? () => setState(() => quantity--) : null,
                            ),
                            Text('$quantity', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: () => setState(() => quantity++),
                            ),
                          ],
                        )
                      ],
                    ),
                  ],
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'No pricing rule configured for this combination.',
                  style: TextStyle(color: Colors.redAccent, fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                ),
              ),

          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: activePricing == null
                ? null
                : () {
                    final discount = double.tryParse(_discountController.text) ?? 0.0;
                    ref.read(addOrderProvider.notifier).addItem(activePricing!, quantity, discount);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Item added to cart!'), duration: Duration(seconds: 1)),
                    );
                  },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Add to Order', style: TextStyle(fontSize: 16)),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _CustomerSelectionSheet extends StatefulWidget {
  final List<Map<String, String>> customers;
  final ValueChanged<Map<String, String>> onSelected;

  const _CustomerSelectionSheet({
    required this.customers,
    required this.onSelected,
  });

  @override
  State<_CustomerSelectionSheet> createState() => _CustomerSelectionSheetState();
}

class _CustomerSelectionSheetState extends State<_CustomerSelectionSheet> {
  String _searchQuery = '';
  late List<Map<String, String>> _filteredCustomers;

  @override
  void initState() {
    super.initState();
    _filteredCustomers = widget.customers;
  }

  void _filterCustomers(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredCustomers = widget.customers;
      } else {
        _filteredCustomers = widget.customers.where((c) {
          final name = c['name']!.toLowerCase();
          final phone = c['phone']!.toLowerCase();
          final q = query.toLowerCase();
          return name.contains(q) || phone.contains(q);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.only(
        top: 16,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).padding.bottom + bottomInset + 16,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Select Returning Customer',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: InputDecoration(
              hintText: 'Search by name or phone...',
              prefixIcon: const Icon(LucideIcons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: _filterCustomers,
          ),
          const SizedBox(height: 16),
          if (_filteredCustomers.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.users, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 12),
                    Text(
                      _searchQuery.isEmpty ? 'No previous customers found' : 'No matching customers found',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: _filteredCustomers.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final customer = _filteredCustomers[index];
                  final name = customer['name']!;
                  final phone = customer['phone']!;
                  final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 4),
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                      foregroundColor: AppTheme.primaryColor,
                      child: Text(initial, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(phone.isNotEmpty ? phone : 'No phone number'),
                    onTap: () {
                      widget.onSelected(customer);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

