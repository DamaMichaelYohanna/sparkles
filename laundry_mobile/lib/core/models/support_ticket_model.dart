class SupportTicketModel {
  final String id;
  final String title;
  final String description;
  final String ticketType; // 'feature_request', 'complaint', 'feedback'
  final String status; // 'pending', 'in_progress', 'resolved', 'closed'
  final String adminNotes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  final String syncStatus;

  SupportTicketModel({
    required this.id,
    required this.title,
    required this.description,
    required this.ticketType,
    required this.status,
    this.adminNotes = '',
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.syncStatus = 'pending',
  });

  factory SupportTicketModel.fromDb(Map<String, dynamic> map) {
    return SupportTicketModel(
      id: map['id'] as String,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      ticketType: map['ticket_type'] as String? ?? 'feedback',
      status: map['status'] as String? ?? 'pending',
      adminNotes: map['admin_notes'] as String? ?? '',
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
      'title': title,
      'description': description,
      'ticket_type': ticketType,
      'status': status,
      'admin_notes': adminNotes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_deleted': isDeleted ? 1 : 0,
      'sync_status': syncStatus,
    };
  }

  factory SupportTicketModel.fromJson(Map<String, dynamic> json) {
    return SupportTicketModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      ticketType: json['ticket_type'] as String? ?? 'feedback',
      status: json['status'] as String? ?? 'pending',
      adminNotes: json['admin_notes'] as String? ?? '',
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']).toUtc() 
          : DateTime.now().toUtc(),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at']).toUtc() 
          : DateTime.now().toUtc(),
      isDeleted: json['is_deleted'] as bool? ?? false,
      syncStatus: 'synced',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'ticket_type': ticketType,
      'status': status,
      'admin_notes': adminNotes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_deleted': isDeleted,
    };
  }

  SupportTicketModel copyWith({
    String? id,
    String? title,
    String? description,
    String? ticketType,
    String? status,
    String? adminNotes,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    String? syncStatus,
  }) {
    return SupportTicketModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      ticketType: ticketType ?? this.ticketType,
      status: status ?? this.status,
      adminNotes: adminNotes ?? this.adminNotes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}
