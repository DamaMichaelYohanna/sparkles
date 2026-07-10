import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/local_db/database_helper.dart';
import '../../core/models/order_model.dart';
import '../../core/theme.dart';
import 'providers/orders_provider.dart';
import '../dashboard/providers/dashboard_provider.dart';
import '../finance/providers/finance_provider.dart';

class OrderDetailScreen extends ConsumerStatefulWidget {
  final OrderModel order;

  const OrderDetailScreen({Key? key, required this.order}) : super(key: key);

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  late OrderModel _order;
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _loadOrderDetails();
  }

  Future<void> _loadOrderDetails() async {
    setState(() => _isLoading = true);
    try {
      // Fetch latest order details from DB to make sure we are fresh
      final db = await DatabaseHelper.instance.database;
      final orderData = await db.query('orders', where: 'id = ?', whereArgs: [_order.id]);
      if (orderData.isNotEmpty) {
        _order = OrderModel.fromDb(orderData.first);
      }

      // Fetch items
      final itemsData = await DatabaseHelper.instance.getOrderItemsWithPricing(_order.id);
      setState(() {
        _items = itemsData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading details: $e')),
      );
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    try {
      await DatabaseHelper.instance.updateOrderStatusAndPayment(
        _order.id,
        newStatus,
        _order.amountPaid,
      );
      await _loadOrderDetails();
      
      // Refresh providers to update list UI & trigger delta sync
      ref.invalidate(ordersListProvider);
      ref.invalidate(recentOrdersProvider);
      ref.invalidate(dashboardStatsProvider);
      ref.invalidate(rawFinanceOrdersProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order status updated to $newStatus')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update status: $e')),
      );
    }
  }

  Future<void> _logPayment(double paymentAmount) async {
    if (paymentAmount <= 0) return;
    try {
      final newAmountPaid = _order.amountPaid + paymentAmount;
      String newStatus = _order.status;

      // Automatically complete status if paid in full
      if (newAmountPaid >= _order.totalPrice && _order.status == 'Pending') {
        newStatus = 'Completed';
      }

      await DatabaseHelper.instance.updateOrderStatusAndPayment(
        _order.id,
        newStatus,
        newAmountPaid,
      );
      await _loadOrderDetails();

      // Refresh providers to update list UI & trigger delta sync
      ref.invalidate(ordersListProvider);
      ref.invalidate(recentOrdersProvider);
      ref.invalidate(dashboardStatsProvider);
      ref.invalidate(rawFinanceOrdersProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment of ₦${paymentAmount.toStringAsFixed(2)} recorded successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to record payment: $e')),
      );
    }
  }

  Future<void> _deleteOrder() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Order'),
        content: const Text('Are you sure you want to delete this order? This will soft-delete the order offline and sync the deletion online.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await DatabaseHelper.instance.softDeleteOrder(_order.id);
        
        // Refresh providers to update list UI & trigger delta sync
        ref.invalidate(ordersListProvider);
        ref.invalidate(recentOrdersProvider);
        ref.invalidate(dashboardStatsProvider);
        ref.invalidate(rawFinanceOrdersProvider);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Order deleted')),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete order: $e')),
        );
      }
    }
  }

  void _showPaymentDialog() {
    final controller = TextEditingController();
    final remaining = _order.totalPrice - _order.amountPaid;
    controller.text = remaining > 0 ? remaining.toStringAsFixed(2) : '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Outstanding Balance: ₦${remaining.toStringAsFixed(2)}', 
                style: const TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Amount Paid (₦)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(controller.text) ?? 0.0;
              if (amount > 0) {
                Navigator.pop(context);
                _logPayment(amount);
              }
            },
            child: const Text('Save Payment'),
          ),
        ],
      ),
    );
  }

  void _showStatusBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Change Order Status', 
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(LucideIcons.clock, color: Colors.orange),
                title: const Text('Pending'),
                trailing: _order.status == 'Pending' ? const Icon(Icons.check, color: AppTheme.primaryColor) : null,
                onTap: () {
                  Navigator.pop(context);
                  _updateStatus('Pending');
                },
              ),
              ListTile(
                leading: const Icon(LucideIcons.checkCircle2, color: Colors.green),
                title: const Text('Completed'),
                trailing: _order.status == 'Completed' ? const Icon(Icons.check, color: AppTheme.primaryColor) : null,
                onTap: () {
                  Navigator.pop(context);
                  _updateStatus('Completed');
                },
              ),
              ListTile(
                leading: const Icon(LucideIcons.alertTriangle, color: Colors.red),
                title: const Text('Overdue'),
                trailing: _order.status == 'Overdue' ? const Icon(Icons.check, color: AppTheme.primaryColor) : null,
                onTap: () {
                  Navigator.pop(context);
                  _updateStatus('Overdue');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final balance = _order.totalPrice - _order.amountPaid;
    final isFullyPaid = balance <= 0;

    Color statusColor;
    if (_order.status == 'Completed') {
      statusColor = Colors.green;
    } else if (_order.status == 'Overdue') {
      statusColor = Colors.red;
    } else {
      statusColor = Colors.orange;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Details'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.trash2, color: Colors.redAccent),
            onPressed: _deleteOrder,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Status & Header Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Order #${_order.displayId}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Date: ${_order.displayDate}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          InkWell(
                            onTap: _showStatusBottomSheet,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: statusColor.withOpacity(0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _order.status,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(Icons.arrow_drop_down, color: statusColor, size: 18),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Customer details
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Customer Details',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                          ),
                          const Divider(height: 24),
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: AppTheme.background,
                                child: const Icon(LucideIcons.user, color: AppTheme.textSecondary),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _order.customerName,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _order.customerPhone.isNotEmpty
                                          ? _order.customerPhone
                                          : 'No phone number provided',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_order.customerPhone.isNotEmpty)
                                CircleAvatar(
                                  backgroundColor: Colors.green.withOpacity(0.1),
                                  child: IconButton(
                                    icon: const Icon(LucideIcons.phone, color: Colors.green, size: 18),
                                    onPressed: () {
                                      // Native launcher could go here
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Order items list
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Items Ordered',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                          ),
                          const Divider(height: 24),
                          if (_items.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12.0),
                              child: Text('No items registered for this order.',
                                  style: TextStyle(fontStyle: FontStyle.italic, color: AppTheme.textSecondary)),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _items.length,
                              separatorBuilder: (_, __) => const Divider(height: 20),
                              itemBuilder: (context, index) {
                                final item = _items[index];
                                final itemName = item['item_name'] ?? 'Unknown Item';
                                final quantity = item['quantity'] ?? 1;
                                final unitPrice = item['unit_price'] ?? 0.0;
                                final subtotal = item['subtotal'] ?? 0.0;

                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            itemName,
                                            style: const TextStyle(fontWeight: FontWeight.w600),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Quantity: $quantity × ₦${unitPrice.toStringAsFixed(2)}',
                                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '₦${subtotal.toStringAsFixed(2)}',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Financial Breakdown
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Payment Summary',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                          ),
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total Amount'),
                              Text(
                                '₦${_order.totalPrice.toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Amount Paid'),
                              Text(
                                '₦${_order.amountPaid.toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Remaining Balance',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '₦${balance.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: isFullyPaid ? Colors.green : Colors.redAccent,
                                ),
                              ),
                            ],
                          ),
                          if (!isFullyPaid) ...[
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _showPaymentDialog,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                ),
                                icon: const Icon(LucideIcons.plus, size: 18),
                                label: const Text('Log Payment'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}
