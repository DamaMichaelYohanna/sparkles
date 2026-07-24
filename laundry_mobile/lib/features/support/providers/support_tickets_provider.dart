import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/local_db/database_helper.dart';
import '../../../core/models/support_ticket_model.dart';
import '../../../core/providers.dart';

class SupportTicketsNotifier extends Notifier<List<SupportTicketModel>> {
  @override
  List<SupportTicketModel> build() {
    _loadTickets();
    return [];
  }

  Future<void> _loadTickets() async {
    final db = await DatabaseHelper.instance.database;
    final results = await db.query(
      'support_tickets',
      where: 'is_deleted = ?',
      whereArgs: [0],
      orderBy: 'created_at DESC',
    );
    state = results.map((e) => SupportTicketModel.fromDb(e)).toList();
  }

  Future<void> submitTicket({
    required String title,
    required String description,
    required String ticketType,
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now().toUtc();
    
    final newTicket = SupportTicketModel(
      id: id,
      title: title,
      description: description,
      ticketType: ticketType,
      status: 'pending',
      createdAt: now,
      updatedAt: now,
      syncStatus: 'pending',
    );

    // Save locally
    final db = await DatabaseHelper.instance.database;
    await db.insert('support_tickets', newTicket.toDb());

    // Update local state
    state = [newTicket, ...state];

    // Trigger sync to upload it to the backend immediately if online
    ref.read(syncRepositoryProvider).triggerSync();
  }
  
  Future<void> refresh() async {
    await _loadTickets();
  }
}

final supportTicketsListProvider = NotifierProvider.autoDispose<SupportTicketsNotifier, List<SupportTicketModel>>(
  () => SupportTicketsNotifier(),
);
