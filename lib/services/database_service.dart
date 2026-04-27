import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/expense.dart';

class DatabaseService {
  // Singleton pattern - only one database instance exists
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;

  // Get database instance (creates one if doesn't exist)
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // Initialize the database
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'senangduit.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  // Create tables when database is first created
  Future<void> _onCreate(Database db, int version) async {
    // Expenses table
    await db.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        date INTEGER NOT NULL,
        categoryId TEXT NOT NULL,
        notes TEXT,
        isRecurring INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Budgets table (for monthly budgets)
    await db.execute('''
      CREATE TABLE budgets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        categoryId TEXT,
        amount REAL NOT NULL,
        month INTEGER NOT NULL,
        year INTEGER NOT NULL
      )
    ''');
  }

  // ===== EXPENSE OPERATIONS =====

  // Add a new expense
  Future<int> addExpense(Expense expense) async {
    final db = await database;
    return await db.insert('expenses', expense.toMap());
  }

  // Get all expenses (newest first)
  Future<List<Expense>> getAllExpenses() async {
    final db = await database;
    final maps = await db.query(
      'expenses',
      orderBy: 'date DESC',
    );
    return maps.map((map) => Expense.fromMap(map)).toList();
  }

  // Get expenses for current month
  Future<List<Expense>> getCurrentMonthExpenses() async {
    final db = await database;
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final lastDay = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    final maps = await db.query(
      'expenses',
      where: 'date >= ? AND date <= ?',
      whereArgs: [
        firstDay.millisecondsSinceEpoch,
        lastDay.millisecondsSinceEpoch,
      ],
      orderBy: 'date DESC',
    );
    return maps.map((map) => Expense.fromMap(map)).toList();
  }

  // Get expenses by category
  Future<List<Expense>> getExpensesByCategory(String categoryId) async {
    final db = await database;
    final maps = await db.query(
      'expenses',
      where: 'categoryId = ?',
      whereArgs: [categoryId],
      orderBy: 'date DESC',
    );
    return maps.map((map) => Expense.fromMap(map)).toList();
  }

  // Update an expense
  Future<int> updateExpense(Expense expense) async {
    final db = await database;
    return await db.update(
      'expenses',
      expense.toMap(),
      where: 'id = ?',
      whereArgs: [expense.id],
    );
  }

  // Delete an expense
  Future<int> deleteExpense(int id) async {
    final db = await database;
    return await db.delete(
      'expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Get total spending for current month
  Future<double> getCurrentMonthTotal() async {
    final db = await database;
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final lastDay = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM expenses WHERE date >= ? AND date <= ?',
      [firstDay.millisecondsSinceEpoch, lastDay.millisecondsSinceEpoch],
    );

    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  // Get spending breakdown by category for current month
  Future<Map<String, double>> getCategoryBreakdown() async {
    final db = await database;
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final lastDay = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    final result = await db.rawQuery(
      '''SELECT categoryId, SUM(amount) as total 
         FROM expenses 
         WHERE date >= ? AND date <= ?
         GROUP BY categoryId''',
      [firstDay.millisecondsSinceEpoch, lastDay.millisecondsSinceEpoch],
    );

    final breakdown = <String, double>{};
    for (var row in result) {
      breakdown[row['categoryId'] as String] =
          (row['total'] as num).toDouble();
    }
    return breakdown;
  }

  // ===== BUDGET OPERATIONS =====

  // Set monthly budget
  Future<int> setBudget(double amount, {String? categoryId}) async {
    final db = await database;
    final now = DateTime.now();

    // Check if budget already exists for this month
    final existing = await db.query(
      'budgets',
      where: 'month = ? AND year = ? AND categoryId IS ?',
      whereArgs: [now.month, now.year, categoryId],
    );

    if (existing.isNotEmpty) {
      // Update existing budget
      return await db.update(
        'budgets',
        {'amount': amount},
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    } else {
      // Create new budget
      return await db.insert('budgets', {
        'categoryId': categoryId,
        'amount': amount,
        'month': now.month,
        'year': now.year,
      });
    }
  }

  // Get current month's overall budget
  Future<double> getCurrentBudget() async {
    final db = await database;
    final now = DateTime.now();

    final result = await db.query(
      'budgets',
      where: 'month = ? AND year = ? AND categoryId IS NULL',
      whereArgs: [now.month, now.year],
    );

    if (result.isEmpty) return 0.0;
    return (result.first['amount'] as num).toDouble();
  }

  // Clear all data (for testing/reset)
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('expenses');
    await db.delete('budgets');
  }
}