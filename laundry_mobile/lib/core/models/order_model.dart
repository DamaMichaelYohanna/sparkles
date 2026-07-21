class OrderModel {
  final String id;
  final String customerName;
  final String customerPhone;
  final String status;
  final double totalPrice;
  final double amountPaid;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  final String syncStatus;
  final double discountAmount;
  final String trackingCode;

  OrderModel({
    required this.id,
    required this.customerName,
    this.customerPhone = '',
    required this.status,
    required this.totalPrice,
    this.amountPaid = 0.0,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.syncStatus = 'synced',
    this.discountAmount = 0.0,
    this.trackingCode = '',
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    String statusName = 'Unknown';
    if (json['current_status'] is Map) {
      statusName = json['current_status']['name'] ?? 'Unknown';
    } else if (json['current_status'] is String) {
      statusName = json['current_status'];
    }

    return OrderModel(
      id: json['id'] ?? '',
      customerName: json['customer_name'] ?? 'Unknown Customer',
      customerPhone: json['customer_phone'] ?? '',
      status: statusName,
      totalPrice: double.tryParse(json['total_price']?.toString() ?? '0.0') ?? 0.0,
      amountPaid: double.tryParse(json['amount_paid']?.toString() ?? '0.0') ?? 0.0,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']).toUtc() 
          : DateTime.now().toUtc(),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at']).toUtc() 
          : DateTime.now().toUtc(),
      isDeleted: json['is_deleted'] ?? false,
      discountAmount: double.tryParse(json['discount_amount']?.toString() ?? '0.0') ?? 0.0,
      trackingCode: json['tracking_code'] ?? '',
    );
  }

  factory OrderModel.fromDb(Map<String, dynamic> map) {
    return OrderModel(
      id: map['id'] as String,
      customerName: map['customer_name'] as String,
      customerPhone: map['customer_phone'] as String? ?? '',
      status: map['current_status'] as String,
      totalPrice: map['total_price'] as double,
      amountPaid: map['amount_paid'] as double? ?? 0.0,
      createdAt: DateTime.parse(map['created_at'] as String).toUtc(),
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at'] as String).toUtc() : DateTime.now().toUtc(),
      isDeleted: (map['is_deleted'] as int? ?? 0) == 1,
      syncStatus: map['sync_status'] as String? ?? 'synced',
      discountAmount: map['discount_amount'] as double? ?? 0.0,
      trackingCode: map['tracking_code'] as String? ?? '',
    );
  }

  Map<String, dynamic> toDb() {
    return {
      'id': id,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'current_status': status,
      'total_price': totalPrice,
      'amount_paid': amountPaid,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_deleted': isDeleted ? 1 : 0,
      'sync_status': syncStatus,
      'discount_amount': discountAmount,
      'tracking_code': trackingCode,
    };
  }

  String get displayId => id.length > 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase();
  String get displayDate {
    final localDate = createdAt.toLocal();
    return "${localDate.year}-${localDate.month.toString().padLeft(2, '0')}-${localDate.day.toString().padLeft(2, '0')}";
  }
}
