class CustomerModel {
  final String id;
  final String? officeId;
  final String name;
  final String phone;
  final bool isWhatsapp;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  final String syncStatus;

  CustomerModel({
    required this.id,
    this.officeId,
    required this.name,
    required this.phone,
    this.isWhatsapp = false,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.syncStatus = 'synced',
  });

  CustomerModel copyWith({
    String? id,
    String? officeId,
    String? name,
    String? phone,
    bool? isWhatsapp,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    String? syncStatus,
  }) {
    return CustomerModel(
      id: id ?? this.id,
      officeId: officeId ?? this.officeId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      isWhatsapp: isWhatsapp ?? this.isWhatsapp,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    return CustomerModel(
      id: json['id'] ?? '',
      officeId: json['office'] as String?,
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      isWhatsapp: json['is_whatsapp'] ?? false,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']).toUtc() : DateTime.now().toUtc(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']).toUtc() : DateTime.now().toUtc(),
      isDeleted: json['is_deleted'] ?? false,
    );
  }

  factory CustomerModel.fromDb(Map<String, dynamic> map) {
    return CustomerModel(
      id: map['id'] as String,
      officeId: map['office_id'] as String?,
      name: map['name'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      isWhatsapp: (map['is_whatsapp'] as int? ?? 0) == 1,
      createdAt: DateTime.parse(map['created_at'] as String).toUtc(),
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at'] as String).toUtc() : DateTime.now().toUtc(),
      isDeleted: (map['is_deleted'] as int? ?? 0) == 1,
      syncStatus: map['sync_status'] as String? ?? 'synced',
    );
  }

  Map<String, dynamic> toDb() {
    return {
      'id': id,
      'office_id': officeId,
      'name': name,
      'phone': phone,
      'is_whatsapp': isWhatsapp ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_deleted': isDeleted ? 1 : 0,
      'sync_status': syncStatus,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'office': officeId,
      'name': name,
      'phone': phone,
      'is_whatsapp': isWhatsapp,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_deleted': isDeleted,
    };
  }
}
