class OrderModel {
  final String id;
  final String customerName;
  final String status;
  final double totalPrice;
  final DateTime createdAt;

  OrderModel({
    required this.id,
    required this.customerName,
    required this.status,
    required this.totalPrice,
    required this.createdAt,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    // Assuming backend returns current_status as an object or just the ID. 
    // Usually a nested serializer returns an object or a string representation.
    // If it's a UUID, we'd need to resolve it. Assuming it returns the status name for now or we map it.
    // We'll extract 'name' if it's a dict, else just toString.
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

  // For compatibility with mock data shape in UI until fully refactored
  String get displayId => id.length > 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase();
  String get displayDate => "${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}";
}
