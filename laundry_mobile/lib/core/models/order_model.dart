class OrderModel {
  final String id;
  final String customerName;
  final String status;
  final double totalPrice;
  final DateTime createdAt;
  final String syncStatus;

  OrderModel({
    required this.id,
    required this.customerName,
    required this.status,
    required this.totalPrice,
    required this.createdAt,
    this.syncStatus = 'synced',
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
      status: statusName,
      totalPrice: double.tryParse(json['total_price']?.toString() ?? '0.0') ?? 0.0,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
    );
  }

  factory OrderModel.fromDb(Map<String, dynamic> map) {
    return OrderModel(
      id: map['id'] as String,
      customerName: map['customer_name'] as String,
      status: map['current_status'] as String,
      totalPrice: map['total_price'] as double,
      createdAt: DateTime.parse(map['created_at'] as String),
      syncStatus: map['sync_status'] as String? ?? 'synced',
    );
  }

  Map<String, dynamic> toDb() {
    return {
      'id': id,
      'customer_name': customerName,
      'current_status': status,
      'total_price': totalPrice,
      'created_at': createdAt.toIso8601String(),
      'sync_status': syncStatus,
    };
  }

  String get displayId => id.length > 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase();
  String get displayDate => "\${createdAt.year}-\${createdAt.month.toString().padLeft(2, '0')}-\${createdAt.day.toString().padLeft(2, '0')}";
}
