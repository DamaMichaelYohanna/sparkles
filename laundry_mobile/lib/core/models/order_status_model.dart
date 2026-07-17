class OrderStatusModel {
  final String id;
  final String name;
  final int sequenceOrder;
  final bool isCompletedState;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  final String syncStatus;

  OrderStatusModel({
    required this.id,
    required this.name,
    required this.sequenceOrder,
    required this.isCompletedState,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.syncStatus = 'synced',
  });

  factory OrderStatusModel.fromJson(Map<String, dynamic> json) {
    return OrderStatusModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      sequenceOrder: json['sequence_order'] ?? 0,
      isCompletedState: json['is_completed_state'] ?? false,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']).toUtc() : DateTime.now().toUtc(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']).toUtc() : DateTime.now().toUtc(),
      isDeleted: json['is_deleted'] ?? false,
    );
  }

  factory OrderStatusModel.fromDb(Map<String, dynamic> map) {
    return OrderStatusModel(
      id: map['id'] as String,
      name: map['name'] as String,
      sequenceOrder: map['sequence_order'] as int,
      isCompletedState: (map['is_completed_state'] as int? ?? 0) == 1,
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
      'sequence_order': sequenceOrder,
      'is_completed_state': isCompletedState ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_deleted': isDeleted ? 1 : 0,
      'sync_status': syncStatus,
    };
  }
}
