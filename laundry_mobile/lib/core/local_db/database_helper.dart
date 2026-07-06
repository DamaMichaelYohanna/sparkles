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
  sync_status TEXT
)
''');

    await db.execute('''
CREATE TABLE offices (
  id TEXT PRIMARY KEY,
  name TEXT,
  contact_info TEXT,
  subscription_tier TEXT,
  preferences TEXT,
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
  sync_status TEXT
)
''');
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
