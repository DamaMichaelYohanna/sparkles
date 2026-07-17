import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:laundry_mobile/core/models/order_model.dart';
import 'package:laundry_mobile/core/models/order_item_model.dart';
import 'package:laundry_mobile/core/models/item_pricing_model.dart';
import 'package:laundry_mobile/core/local_db/database_helper.dart';
import 'orders_provider.dart';
import '../../dashboard/providers/dashboard_provider.dart';
import '../../analysis/providers/analysis_provider.dart';

// Provides the items available to be selected in the Add Order screen
final itemPricingListProvider = FutureProvider.autoDispose<List<ItemPricingModel>>((ref) async {
  final db = await DatabaseHelper.instance.database;
  final results = await db.query('item_pricing', where: 'is_deleted = ?', whereArgs: [0]);
  return results.map((e) => ItemPricingModel.fromDb(e)).toList();
});

class DraftOrderState {
  final String? existingOrderId;
  final String customerName;
  final String customerPhone;
  final List<OrderItemModel> items;
  final double orderDiscount;
  final String status;
  final double amountPaid;
  final DateTime? createdAt;

  DraftOrderState({
    this.existingOrderId,
    this.customerName = '',
    this.customerPhone = '',
    this.items = const [],
    this.orderDiscount = 0.0,
    this.status = 'Pending',
    this.amountPaid = 0.0,
    this.createdAt,
  });

  DraftOrderState copyWith({
    String? existingOrderId,
    String? customerName,
    String? customerPhone,
    List<OrderItemModel>? items,
    double? orderDiscount,
    String? status,
    double? amountPaid,
    DateTime? createdAt,
  }) {
    return DraftOrderState(
      existingOrderId: existingOrderId ?? this.existingOrderId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      items: items ?? this.items,
      orderDiscount: orderDiscount ?? this.orderDiscount,
      status: status ?? this.status,
      amountPaid: amountPaid ?? this.amountPaid,
      createdAt: createdAt ?? this.createdAt,
    );
  }
  
  double get total {
    final itemsSum = items.fold(0.0, (sum, item) => sum + item.subtotal);
    final finalSum = itemsSum - orderDiscount;
    return finalSum < 0 ? 0.0 : finalSum;
  }
}

class AddOrderNotifier extends Notifier<DraftOrderState> {
  @override
  DraftOrderState build() {
    return DraftOrderState();
  }

  void initializeFromOrder(OrderModel order, List<OrderItemModel> items) {
    state = DraftOrderState(
      existingOrderId: order.id,
      customerName: order.customerName,
      customerPhone: order.customerPhone,
      items: items,
      orderDiscount: order.discountAmount,
      status: order.status,
      amountPaid: order.amountPaid,
      createdAt: order.createdAt,
    );
  }

  void resetState() {
    state = DraftOrderState();
  }

  void updateCustomerInfo({String? name, String? phone}) {
    state = state.copyWith(
      customerName: name ?? state.customerName,
      customerPhone: phone ?? state.customerPhone,
    );
  }

  void updateOrderDiscount(double discount) {
    state = state.copyWith(orderDiscount: discount);
  }

  void updateAmountPaid(double amount) {
    state = state.copyWith(amountPaid: amount);
  }

  void addItem(ItemPricingModel pricing, int quantity, double discountAmount) {
    // Generate a temporary order ID if we haven't yet, or just use empty string for the draft.
    // The final order ID will be assigned when saving.
    final double subtotal = (pricing.price * quantity) - discountAmount;
    final newItem = OrderItemModel(
      id: const Uuid().v4(),
      orderId: '', // placeholder
      itemPricingId: pricing.id,
      quantity: quantity,
      unitPrice: pricing.price,
      discountAmount: discountAmount,
      subtotal: subtotal < 0 ? 0.0 : subtotal,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      syncStatus: 'pending',
    );

    // Check if item already in cart
    final existingIndex = state.items.indexWhere((item) => item.itemPricingId == pricing.id);
    if (existingIndex >= 0) {
      final existingItem = state.items[existingIndex];
      final newQuantity = existingItem.quantity + quantity;
      final newDiscount = existingItem.discountAmount + discountAmount;
      final double newSubtotal = (existingItem.unitPrice * newQuantity) - newDiscount;
      final updatedItem = OrderItemModel(
        id: existingItem.id,
        orderId: existingItem.orderId,
        itemPricingId: existingItem.itemPricingId,
        quantity: newQuantity,
        unitPrice: existingItem.unitPrice,
        discountAmount: newDiscount,
        subtotal: newSubtotal < 0 ? 0.0 : newSubtotal,
        createdAt: existingItem.createdAt,
        updatedAt: DateTime.now(),
        syncStatus: 'pending',
      );
      final updatedList = List<OrderItemModel>.from(state.items)..[existingIndex] = updatedItem;
      state = state.copyWith(items: updatedList);
    } else {
      state = state.copyWith(items: [...state.items, newItem]);
    }
  }

  void removeItem(int index) {
    final updatedList = List<OrderItemModel>.from(state.items)..removeAt(index);
    state = state.copyWith(items: updatedList);
  }

  Future<void> saveOrder() async {
    if (state.customerName.isEmpty || state.items.isEmpty) {
      throw Exception("Customer name and at least one item are required.");
    }

    final isEditing = state.existingOrderId != null;
    final orderId = state.existingOrderId ?? const Uuid().v4();
    final now = DateTime.now();

    final order = OrderModel(
      id: orderId,
      customerName: state.customerName,
      status: state.status,
      totalPrice: state.total,
      createdAt: state.createdAt ?? now,
      updatedAt: now,
      syncStatus: 'pending',
      discountAmount: state.orderDiscount,
      customerPhone: state.customerPhone,
      amountPaid: state.amountPaid,
    );

    final db = await DatabaseHelper.instance.database;

    if (isEditing) {
      // Update order table
      await db.update(
        'orders',
        order.toDb()..addAll({'customer_phone': state.customerPhone, 'amount_paid': state.amountPaid}),
        where: 'id = ?',
        whereArgs: [orderId],
      );
      // Delete old items so we can overwrite them
      await db.delete('order_items', where: 'order_id = ?', whereArgs: [orderId]);
    } else {
      // Save order as new
      await DatabaseHelper.instance.insertOrder(order.toDb()..addAll({'customer_phone': state.customerPhone, 'amount_paid': state.amountPaid}));
    }

    // Save items
    for (var item in state.items) {
      final finalItem = OrderItemModel(
        id: item.id,
        orderId: orderId,
        itemPricingId: item.itemPricingId,
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        discountAmount: item.discountAmount,
        subtotal: item.subtotal,
        createdAt: item.createdAt,
        updatedAt: now,
        syncStatus: 'pending',
      );
      await DatabaseHelper.instance.insertOrderItem(finalItem.toDb());
    }

    // Reset draft state
    state = DraftOrderState();

    // Invalidate caches to refresh data across pages
    ref.invalidate(ordersListProvider);
    ref.invalidate(recentOrdersProvider);
    ref.invalidate(dashboardStatsProvider);
    ref.invalidate(rawAnalysisOrdersProvider);
  }
}

final addOrderProvider = NotifierProvider<AddOrderNotifier, DraftOrderState>(() {
  return AddOrderNotifier();
});
