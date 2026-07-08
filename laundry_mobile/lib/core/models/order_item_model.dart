class OrderItemModel {
  final String id;
  final String orderId;
  final String itemPricingId;
  final int quantity;
  final double unitPrice;
  final double discountAmount;
  final double subtotal;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  final String syncStatus;

  OrderItemModel({
    required this.id,
    required this.orderId,
    required this.itemPricingId,
    required this.quantity,
    required this.unitPrice,
    required this.discountAmount,
    required this.subtotal,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.syncStatus = 'synced',
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      id: json['id'] ?? '',
      orderId: json['order'] ?? '',
      itemPricingId: json['item_pricing'] ?? '',
      quantity: json['quantity'] ?? 1,
      unitPrice: double.tryParse(json['unit_price']?.toString() ?? '0.0') ?? 0.0,
      discountAmount: double.tryParse(json['discount_amount']?.toString() ?? '0.0') ?? 0.0,
      subtotal: double.tryParse(json['subtotal']?.toString() ?? '0.0') ?? 0.0,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : DateTime.now(),
      isDeleted: json['is_deleted'] ?? false,
    );
  }

  factory OrderItemModel.fromDb(Map<String, dynamic> map) {
    return OrderItemModel(
      id: map['id'] as String,
      orderId: map['order_id'] as String,
      itemPricingId: map['item_pricing_id'] as String,
      quantity: map['quantity'] as int,
      unitPrice: map['unit_price'] as double,
      discountAmount: map['discount_amount'] as double,
      subtotal: map['subtotal'] as double,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at'] as String) : DateTime.now(),
      isDeleted: (map['is_deleted'] as int? ?? 0) == 1,
      syncStatus: map['sync_status'] as String? ?? 'synced',
    );
  }

  Map<String, dynamic> toDb() {
    return {
      'id': id,
      'order_id': orderId,
      'item_pricing_id': itemPricingId,
      'quantity': quantity,
      'unit_price': unitPrice,
      'discount_amount': discountAmount,
      'subtotal': subtotal,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_deleted': isDeleted ? 1 : 0,
      'sync_status': syncStatus,
    };
  }
}
