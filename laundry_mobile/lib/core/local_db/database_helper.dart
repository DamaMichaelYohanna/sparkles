import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('laundry_offline.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
CREATE TABLE orders (
  id TEXT PRIMARY KEY,
  customer_name TEXT,
  customer_phone TEXT,
  total_price REAL,
  amount_paid REAL,
  current_status TEXT,
  created_at TEXT,
  updated_at TEXT,
  is_deleted INTEGER DEFAULT 0,
  sync_status TEXT
)
''');

    await db.execute('''
CREATE TABLE order_items (
  id TEXT PRIMARY KEY,
  order_id TEXT,
  item_pricing_id TEXT,
  quantity INTEGER,
  unit_price REAL,
  discount_amount REAL,
  subtotal REAL,
  created_at TEXT,
  updated_at TEXT,
  is_deleted INTEGER DEFAULT 0,
  sync_status TEXT
)
''');

    await db.execute('''
CREATE TABLE service_types (
  id TEXT PRIMARY KEY,
  name TEXT,
  description TEXT,
  created_at TEXT,
  updated_at TEXT,
  is_deleted INTEGER DEFAULT 0,
  sync_status TEXT
)
''');

    await db.execute('''
CREATE TABLE categories (
  id TEXT PRIMARY KEY,
  name TEXT,
  created_at TEXT,
  updated_at TEXT,
  is_deleted INTEGER DEFAULT 0,
  sync_status TEXT
)
''');

    await db.execute('''
CREATE TABLE order_statuses (
  id TEXT PRIMARY KEY,
  name TEXT,
  sequence_order INTEGER,
  is_completed_state INTEGER DEFAULT 0,
  created_at TEXT,
  updated_at TEXT,
  is_deleted INTEGER DEFAULT 0,
  sync_status TEXT
)
''');

    await db.execute('''
CREATE TABLE item_pricing (
  id TEXT PRIMARY KEY,
  name TEXT,
  price REAL,
  category_id TEXT,
  service_type_id TEXT,
  created_at TEXT,
  updated_at TEXT,
  is_deleted INTEGER DEFAULT 0,
  sync_status TEXT
)
''');
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }

  // --- CRUD for Orders ---
  Future<void> insertOrder(Map<String, dynamic> orderData) async {
    final db = await database;
    await db.insert('orders', orderData, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertOrderItem(Map<String, dynamic> itemData) async {
    final db = await database;
    await db.insert('order_items', itemData, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // --- Sync Engine Queries ---
  Future<Map<String, dynamic>> getPendingSyncRecords() async {
    final db = await database;
    
    final pendingOrders = await db.query('orders', where: 'sync_status = ?', whereArgs: ['pending']);
    final pendingItems = await db.query('order_items', where: 'sync_status = ?', whereArgs: ['pending']);
    
    return {
      'orders': pendingOrders,
      'order_items': pendingItems,
    };
  }

  Future<void> markRecordsAsSynced() async {
    final db = await database;
    
    await db.update('orders', {'sync_status': 'synced'}, where: 'sync_status = ?', whereArgs: ['pending']);
    await db.update('order_items', {'sync_status': 'synced'}, where: 'sync_status = ?', whereArgs: ['pending']);
  }
}
