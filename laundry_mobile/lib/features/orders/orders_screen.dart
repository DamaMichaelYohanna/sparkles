import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme.dart';
import 'add_order_screen.dart';
import 'order_detail_screen.dart';
import 'providers/orders_provider.dart';
import '../../core/widgets/sync_badge.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    final currentQuery = ref.read(ordersFilterProvider).searchQuery;
    _searchController = TextEditingController(text: currentQuery);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showFilterBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const OrdersFilterBottomSheet(),
    );
  }

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year.toString().substring(2)}";
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(filteredOrdersListProvider);
    final filter = ref.watch(ordersFilterProvider);
    final filterNotifier = ref.read(ordersFilterProvider.notifier);

    final hasActiveFilters = filter.status != 'All' ||
        filter.paymentStatus != 'All' ||
        filter.dateRange != 'All Time';

    ref.listen<OrdersFilterState>(ordersFilterProvider, (previous, next) {
      if (next.searchQuery.isEmpty && _searchController.text.isNotEmpty) {
        _searchController.clear();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders Management'),
        actions: [
          IconButton(
            icon: Stack(
              children: [
                const Icon(LucideIcons.slidersHorizontal, size: 20),
                if (hasActiveFilters)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () => _showFilterBottomSheet(context),
          ),
          const SyncBadge(),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('last_sync_timestamp');
          ref.invalidate(ordersListProvider);
        },
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by customer name or phone...',
                  prefixIcon: const Icon(LucideIcons.search, size: 18),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            filterNotifier.setSearchQuery('');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.primaryColor),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  filled: true,
                  fillColor: Colors.white,
                ),
                onChanged: (val) {
                  filterNotifier.setSearchQuery(val);
                },
              ),
            ),
            // Active Filter Chips (Only shown if filters are active)
            if (hasActiveFilters)
              Container(
                height: 48,
                color: AppTheme.background.withOpacity(0.5),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  children: [
                    Row(
                      children: [
                        const Icon(LucideIcons.filter, size: 14, color: AppTheme.textSecondary),
                        const SizedBox(width: 8),
                        if (filter.dateRange != 'All Time')
                          Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: InputChip(
                              label: Text(
                                filter.dateRange == 'Custom' && filter.customDateRange != null
                                    ? "${_formatDate(filter.customDateRange!.start)} - ${_formatDate(filter.customDateRange!.end)}"
                                    : filter.dateRange,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                              onDeleted: () => filterNotifier.setDateRange('All Time'),
                              deleteIcon: const Icon(Icons.close, size: 14),
                              deleteIconColor: AppTheme.primaryColor,
                              backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                              side: BorderSide.none,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                          ),
                        if (filter.status != 'All')
                          Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: InputChip(
                              label: Text(
                                "Status: ${filter.status}",
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                              onDeleted: () => filterNotifier.setStatus('All'),
                              deleteIcon: const Icon(Icons.close, size: 14),
                              deleteIconColor: AppTheme.primaryColor,
                              backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                              side: BorderSide.none,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                          ),
                        if (filter.paymentStatus != 'All')
                          Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: InputChip(
                              label: Text(
                                "Payment: ${filter.paymentStatus}",
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                              onDeleted: () => filterNotifier.setPaymentStatus('All'),
                              deleteIcon: const Icon(Icons.close, size: 14),
                              deleteIconColor: AppTheme.primaryColor,
                              backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                              side: BorderSide.none,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                          ),
                        TextButton(
                          onPressed: () => filterNotifier.reset(),
                          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 30)),
                          child: const Text('Clear All', style: TextStyle(fontSize: 11, color: Colors.redAccent, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            if (hasActiveFilters) const Divider(height: 1),

            // Orders List
            Expanded(
              child: ordersAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(child: Text('Error: $error')),
                data: (filteredOrders) {
                  if (filteredOrders.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.shoppingBag, size: 48, color: AppTheme.textSecondary.withOpacity(0.5)),
                          const SizedBox(height: 12),
                          const Text('No orders found matching filters.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16).copyWith(top: 12),
                    itemCount: filteredOrders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final order = filteredOrders[index];

                      // Resolve order status colors
                      Color statusColor;
                      if (order.status == 'Completed') {
                        statusColor = Colors.green;
                      } else if (order.status == 'Overdue') {
                        statusColor = Colors.red;
                      } else {
                        statusColor = Colors.orange;
                      }

                      // Resolve payment status colors
                      final balance = order.totalPrice - order.amountPaid;
                      String payStatus = 'Unpaid';
                      Color payColor = Colors.redAccent;
                      if (balance <= 0 && order.totalPrice > 0) {
                        payStatus = 'Fully Paid';
                        payColor = Colors.green;
                      } else if (order.amountPaid > 0) {
                        payStatus = 'Partially Paid';
                        payColor = Colors.orange;
                      }

                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: AppTheme.background, width: 2),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          title: Text(
                            order.customerName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text('Order: #${order.displayId} • ${order.displayDate}'),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '₦${order.totalPrice.toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      order.status,
                                      style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: payColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      payStatus,
                                      style: TextStyle(color: payColor, fontSize: 9, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => OrderDetailScreen(order: order),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const AddOrderScreen()));
        },
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class OrdersFilterBottomSheet extends ConsumerWidget {
  const OrdersFilterBottomSheet({Key? key}) : super(key: key);

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year.toString().substring(2)}";
  }

  Future<void> _pickCustomDateRange(BuildContext context, WidgetRef ref, DateTimeRange? currentRange) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2025),
      lastDate: DateTime(2030),
      initialDateRange: currentRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.white,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      ref.read(ordersFilterProvider.notifier).setCustomDateRange(picked);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(ordersFilterProvider);
    final filterNotifier = ref.read(ordersFilterProvider.notifier);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 8,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag indicator
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Filter Orders',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              TextButton(
                onPressed: () => filterNotifier.reset(),
                child: const Text('Reset All', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 12),

          // 1. Date filters
          const Text('Date Period', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ...['All Time', 'Today', 'This Week', 'This Month'].map((range) {
                final isSelected = filter.dateRange == range;
                return ChoiceChip(
                  label: Text(range, style: const TextStyle(fontSize: 11)),
                  selected: isSelected,
                  onSelected: (_) => filterNotifier.setDateRange(range),
                  selectedColor: AppTheme.primaryColor.withOpacity(0.15),
                  backgroundColor: Colors.grey.shade100,
                  side: BorderSide(color: isSelected ? AppTheme.primaryColor : Colors.transparent),
                  labelStyle: TextStyle(
                    color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 8),
          
          // Calendar picker button
          GestureDetector(
            onTap: () => _pickCustomDateRange(context, ref, filter.customDateRange),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: filter.dateRange == 'Custom' ? AppTheme.primaryColor.withOpacity(0.08) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: filter.dateRange == 'Custom' ? AppTheme.primaryColor : Colors.transparent,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    LucideIcons.calendar,
                    size: 16,
                    color: filter.dateRange == 'Custom' ? AppTheme.primaryColor : AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    filter.dateRange == 'Custom' && filter.customDateRange != null
                        ? "${_formatDate(filter.customDateRange!.start)} - ${_formatDate(filter.customDateRange!.end)}"
                        : 'Select Calendar Range',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: filter.dateRange == 'Custom' ? FontWeight.bold : FontWeight.normal,
                      color: filter.dateRange == 'Custom' ? AppTheme.primaryColor : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 2. Order Status
          const Text('Order Progress', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ...['All', 'Pending', 'Completed', 'Overdue'].map((status) {
                final isSelected = filter.status == status;
                return ChoiceChip(
                  label: Text(status, style: const TextStyle(fontSize: 11)),
                  selected: isSelected,
                  onSelected: (_) => filterNotifier.setStatus(status),
                  selectedColor: AppTheme.primaryColor.withOpacity(0.15),
                  backgroundColor: Colors.grey.shade100,
                  side: BorderSide(color: isSelected ? AppTheme.primaryColor : Colors.transparent),
                  labelStyle: TextStyle(
                    color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 20),

          // 3. Payment Status
          const Text('Payment Status', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ...['All', 'Fully Paid', 'Partially Paid', 'Unpaid'].map((payStatus) {
                final isSelected = filter.paymentStatus == payStatus;
                return ChoiceChip(
                  label: Text(payStatus, style: const TextStyle(fontSize: 11)),
                  selected: isSelected,
                  onSelected: (_) => filterNotifier.setPaymentStatus(payStatus),
                  selectedColor: AppTheme.primaryColor.withOpacity(0.15),
                  backgroundColor: Colors.grey.shade100,
                  side: BorderSide(color: isSelected ? AppTheme.primaryColor : Colors.transparent),
                  labelStyle: TextStyle(
                    color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 24),

          // Apply Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Apply Filters', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
