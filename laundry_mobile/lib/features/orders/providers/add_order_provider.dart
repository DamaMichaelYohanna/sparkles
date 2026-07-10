import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:laundry_mobile/core/models/order_model.dart';
import 'package:laundry_mobile/core/models/order_item_model.dart';
import 'package:laundry_mobile/core/models/item_pricing_model.dart';
import 'package:laundry_mobile/core/local_db/database_helper.dart';
import 'orders_provider.dart';
import '../../dashboard/providers/dashboard_provider.dart';
import '../../finance/providers/finance_provider.dart';

// Provides the items available to be selected in the Add Order screen
final itemPricingListProvider = FutureProvider.autoDispose<List<ItemPricingModel>>((ref) async {
  final db = await DatabaseHelper.instance.database;
  final results = await db.query('item_pricing', where: 'is_deleted = ?', whereArgs: [0]);
  return results.map((e) => ItemPricingModel.fromDb(e)).toList();
});

class DraftOrderState {
  final String customerName;
  final String customerPhone;
  final List<OrderItemModel> items;

  DraftOrderState({
    this.customerName = '',
    this.customerPhone = '',
    this.items = const [],
  });

  DraftOrderState copyWith({
    String? customerName,
    String? customerPhone,
    List<OrderItemModel>? items,
  }) {
    return DraftOrderState(
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      items: items ?? this.items,
    );
  }
  
  double get total => items.fold(0.0, (sum, item) => sum + item.subtotal);
}

class AddOrderNotifier extends Notifier<DraftOrderState> {
  @override
  DraftOrderState build() {
    return DraftOrderState();
  }

  void updateCustomerInfo({String? name, String? phone}) {
    state = state.copyWith(
      customerName: name,
      customerPhone: phone,
    );
  }

  void addItem(ItemPricingModel pricing, int quantity) {
    // Generate a temporary order ID if we haven't yet, or just use empty string for the draft.
    // The final order ID will be assigned when saving.
    final newItem = OrderItemModel(
      id: const Uuid().v4(),
      orderId: '', // placeholder
      itemPricingId: pricing.id,
      quantity: quantity,
      unitPrice: pricing.price,
      discountAmount: 0.0,
      subtotal: pricing.price * quantity,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      syncStatus: 'pending',
    );

    // Check if item already in cart
    final existingIndex = state.items.indexWhere((item) => item.itemPricingId == pricing.id);
    if (existingIndex >= 0) {
      final existingItem = state.items[existingIndex];
      final newQuantity = existingItem.quantity + quantity;
      final updatedItem = OrderItemModel(
        id: existingItem.id,
        orderId: existingItem.orderId,
        itemPricingId: existingItem.itemPricingId,
        quantity: newQuantity,
        unitPrice: existingItem.unitPrice,
        discountAmount: existingItem.discountAmount,
        subtotal: existingItem.unitPrice * newQuantity,
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

  Future<void> saveOrder() async {
    if (state.customerName.isEmpty || state.items.isEmpty) {
      throw Exception("Customer name and at least one item are required.");
    }

    final orderId = const Uuid().v4();
    final now = DateTime.now();

    final order = OrderModel(
      id: orderId,
      customerName: state.customerName,
      status: 'Pending',
      totalPrice: state.total,
      createdAt: now,
      updatedAt: now,
      syncStatus: 'pending',
    );

    // Save order
    await DatabaseHelper.instance.insertOrder(order.toDb()..addAll({'customer_phone': state.customerPhone, 'amount_paid': 0.0}));

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
    ref.invalidate(rawFinanceOrdersProvider);
  }
}

final addOrderProvider = NotifierProvider<AddOrderNotifier, DraftOrderState>(() {
  return AddOrderNotifier();
});
