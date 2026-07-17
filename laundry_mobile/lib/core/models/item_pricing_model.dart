class ItemPricingModel {
  final String id;
  final String name;
  final double price;
  final String categoryId;
  final String serviceTypeId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  final String syncStatus;

  ItemPricingModel({
    required this.id,
    required this.name,
    required this.price,
    required this.categoryId,
    required this.serviceTypeId,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.syncStatus = 'synced',
  });

  factory ItemPricingModel.fromJson(Map<String, dynamic> json) {
    return ItemPricingModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      price: double.tryParse(json['price']?.toString() ?? '0.0') ?? 0.0,
      categoryId: json['category'] ?? '', // backend might return category object or ID depending on serializer, assuming ID for now or adjusting in view
      serviceTypeId: json['service_type'] ?? '',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']).toUtc() : DateTime.now().toUtc(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']).toUtc() : DateTime.now().toUtc(),
      isDeleted: json['is_deleted'] ?? false,
    );
  }

  factory ItemPricingModel.fromDb(Map<String, dynamic> map) {
    return ItemPricingModel(
      id: map['id'] as String,
      name: map['name'] as String,
      price: map['price'] as double,
      categoryId: map['category_id'] as String,
      serviceTypeId: map['service_type_id'] as String,
      createdAt: DateTime.parse(map['created_at'] as String).toUtc(),
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at'] as String).toUtc() : DateTime.now().toUtc(),
      isDeleted: (map['is_deleted'] as int? ?? 0) == 1,
      syncStatus: map['sync_status'] as String? ?? 'synced',
    );
  }

  Map<String, dynamic> toDb() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'category_id': categoryId,
      'service_type_id': serviceTypeId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_deleted': isDeleted ? 1 : 0,
      'sync_status': syncStatus,
    };
  }
}
