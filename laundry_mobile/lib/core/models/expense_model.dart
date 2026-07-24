class ExpenseModel {
  final String id;
  final double amount;
  final String description;
  final String category;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  final String syncStatus;

  ExpenseModel({
    required this.id,
    required this.amount,
    required this.description,
    required this.category,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.syncStatus = 'pending',
  });

  factory ExpenseModel.fromDb(Map<String, dynamic> map) {
    return ExpenseModel(
      id: map['id'] as String,
      amount: map['amount'] as double,
      description: map['description'] as String? ?? '',
      category: map['category'] as String? ?? 'Others',
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null 
          ? DateTime.parse(map['updated_at'] as String) 
          : DateTime.parse(map['created_at'] as String),
      isDeleted: (map['is_deleted'] as int? ?? 0) == 1,
      syncStatus: map['sync_status'] as String? ?? 'pending',
    );
  }

  Map<String, dynamic> toDb() {
    return {
      'id': id,
      'amount': amount,
      'description': description,
      'category': category,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_deleted': isDeleted ? 1 : 0,
      'sync_status': syncStatus,
    };
  }

  ExpenseModel copyWith({
    String? id,
    double? amount,
    String? description,
    String? category,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    String? syncStatus,
  }) {
    return ExpenseModel(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}
