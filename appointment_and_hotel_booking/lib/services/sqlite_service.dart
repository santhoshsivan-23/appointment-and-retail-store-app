import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/category_model.dart';
import '../models/product_model.dart';

class SqliteService {
  static Database? _database;
  static bool _initializedFfi = false;
  static List<ProductModel>? mockProductsForTesting;
  static List<CategoryModel>? mockCategoriesForTesting;

  /// Check whether we are currently executing in automated testWidgets environment.
  static bool get isTestEnvironment {
    try {
      return !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }

  /// Ensures FFI is initialized on desktop platforms (Windows, Linux).
  static void initFfi() {
    if (_initializedFfi) return;
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    _initializedFfi = true;
  }

  /// Singleton database instance.
  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    initFfi();

    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'appointment_hotel_pos.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS products (
            id INTEGER PRIMARY KEY,
            business_id INTEGER,
            category_id INTEGER,
            name TEXT NOT NULL,
            sku TEXT,
            product_type TEXT,
            price REAL,
            description TEXT,
            modifiers TEXT,
            combo_items TEXT,
            is_active INTEGER DEFAULT 1,
            is_deleted INTEGER DEFAULT 0,
            created_at TEXT,
            updated_at TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS categories (
            id INTEGER PRIMARY KEY,
            business_id INTEGER,
            name TEXT NOT NULL,
            description TEXT,
            icon TEXT,
            sort_order INTEGER DEFAULT 0,
            show_in_appointment INTEGER DEFAULT 1,
            is_active INTEGER DEFAULT 1,
            is_deleted INTEGER DEFAULT 0,
            created_at TEXT,
            updated_at TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS categories (
              id INTEGER PRIMARY KEY,
              business_id INTEGER,
              name TEXT NOT NULL,
              description TEXT,
              icon TEXT,
              sort_order INTEGER DEFAULT 0,
              show_in_appointment INTEGER DEFAULT 1,
              is_active INTEGER DEFAULT 1,
              is_deleted INTEGER DEFAULT 0,
              created_at TEXT,
              updated_at TEXT
            )
          ''');
        }
      },
    );
  }

  // =========================================================================
  // PRODUCT OPERATIONS
  // =========================================================================

  /// Synchronize product list from API into local SQLite database.
  /// Upserts all returned products, and marks any products not in the active list as deleted.
  static Future<int> syncProducts(List<ProductModel> apiProducts) async {
    if (isTestEnvironment && _database == null) {
      mockProductsForTesting = List<ProductModel>.from(apiProducts);
      return apiProducts.length;
    }

    final db = await database;

    return await db.transaction<int>((txn) async {
      final activeIds = apiProducts.map((p) => p.id).toSet();

      // If there are active products from API, mark all others in SQLite as deleted
      if (activeIds.isNotEmpty) {
        final placeholders = List.filled(activeIds.length, '?').join(',');
        await txn.update(
          'products',
          {
            'is_deleted': 1,
            'is_active': 0,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id NOT IN ($placeholders)',
          whereArgs: activeIds.toList(),
        );
      } else {
        await txn.update(
          'products',
          {
            'is_deleted': 1,
            'is_active': 0,
            'updated_at': DateTime.now().toIso8601String(),
          },
        );
      }

      // Upsert all products to avoid duplicates
      for (final product in apiProducts) {
        await txn.insert(
          'products',
          product.toSqliteMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      return apiProducts.length;
    });
  }

  /// Retrieve active (non-deleted) products from local SQLite database.
  static Future<List<ProductModel>> getActiveProducts() async {
    if (mockProductsForTesting != null) {
      return List<ProductModel>.from(mockProductsForTesting!);
    }
    if (isTestEnvironment && _database == null) {
      return [];
    }

    final db = await database;
    final List<Map<String, dynamic>> rows = await db.query(
      'products',
      where: '(is_deleted = 0 OR is_deleted IS NULL) AND is_active = 1',
      orderBy: 'id DESC',
    );
    return rows.map((r) => ProductModel.fromJson(r)).toList();
  }

  /// Search active products locally in SQLite database by name or sku.
  static Future<List<ProductModel>> searchProducts(String query) async {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) {
      return getActiveProducts();
    }
    if (mockProductsForTesting != null) {
      return mockProductsForTesting!
          .where((p) =>
              p.name.toLowerCase().contains(clean) ||
              p.sku.toLowerCase().contains(clean))
          .toList();
    }
    if (isTestEnvironment && _database == null) {
      return [];
    }

    final db = await database;
    final List<Map<String, dynamic>> rows = await db.query(
      'products',
      where: '((is_deleted = 0 OR is_deleted IS NULL) AND is_active = 1) AND (LOWER(name) LIKE ? OR LOWER(sku) LIKE ?)',
      whereArgs: ['%$clean%', '%$clean%'],
      orderBy: 'id DESC',
    );
    return rows.map((r) => ProductModel.fromJson(r)).toList();
  }

  /// Retrieve active products filtered by category from local SQLite database.
  static Future<List<ProductModel>> getProductsByCategory(int? categoryId) async {
    if (categoryId == null) {
      return getActiveProducts();
    }
    if (mockProductsForTesting != null) {
      return mockProductsForTesting!
          .where((p) => p.categoryId == categoryId)
          .toList();
    }
    if (isTestEnvironment && _database == null) {
      return [];
    }

    final db = await database;
    final List<Map<String, dynamic>> rows = await db.query(
      'products',
      where: '((is_deleted = 0 OR is_deleted IS NULL) AND is_active = 1) AND category_id = ?',
      whereArgs: [categoryId],
      orderBy: 'id DESC',
    );
    return rows.map((r) => ProductModel.fromJson(r)).toList();
  }

  /// Retrieve product count from local SQLite database.
  static Future<int> getActiveProductsCount() async {
    if (mockProductsForTesting != null) {
      return mockProductsForTesting!.length;
    }
    if (isTestEnvironment && _database == null) {
      return 0;
    }

    final db = await database;
    final res = await db.rawQuery(
      'SELECT COUNT(*) as total FROM products WHERE (is_deleted = 0 OR is_deleted IS NULL) AND is_active = 1',
    );
    if (res.isNotEmpty && res.first['total'] != null) {
      return int.tryParse(res.first['total'].toString()) ?? 0;
    }
    return 0;
  }

  // =========================================================================
  // CATEGORY OPERATIONS
  // =========================================================================

  /// Synchronize category list from API into local SQLite database.
  /// Upserts all returned categories, and marks any categories not in the active list as deleted.
  static Future<int> syncCategories(List<CategoryModel> apiCategories) async {
    if (isTestEnvironment && _database == null) {
      mockCategoriesForTesting = List<CategoryModel>.from(apiCategories);
      return apiCategories.length;
    }

    final db = await database;

    return await db.transaction<int>((txn) async {
      final activeIds = apiCategories.map((c) => c.id).toSet();

      // If there are active categories from API, mark all others in SQLite as deleted
      if (activeIds.isNotEmpty) {
        final placeholders = List.filled(activeIds.length, '?').join(',');
        await txn.update(
          'categories',
          {
            'is_deleted': 1,
            'is_active': 0,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id NOT IN ($placeholders)',
          whereArgs: activeIds.toList(),
        );
      } else {
        await txn.update(
          'categories',
          {
            'is_deleted': 1,
            'is_active': 0,
            'updated_at': DateTime.now().toIso8601String(),
          },
        );
      }

      // Upsert all categories to avoid duplicates
      for (final category in apiCategories) {
        await txn.insert(
          'categories',
          category.toSqliteMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      return apiCategories.length;
    });
  }

  /// Retrieve active (non-deleted) categories from local SQLite database.
  static Future<List<CategoryModel>> getActiveCategories() async {
    if (mockCategoriesForTesting != null) {
      return List<CategoryModel>.from(mockCategoriesForTesting!);
    }
    if (isTestEnvironment && _database == null) {
      return [];
    }

    final db = await database;
    final List<Map<String, dynamic>> rows = await db.query(
      'categories',
      where: '(is_deleted = 0 OR is_deleted IS NULL) AND is_active = 1',
      orderBy: 'sort_order ASC, name ASC',
    );
    return rows.map((r) => CategoryModel.fromJson(r)).toList();
  }

  /// Retrieve category count from local SQLite database.
  static Future<int> getActiveCategoriesCount() async {
    if (mockCategoriesForTesting != null) {
      return mockCategoriesForTesting!.length;
    }
    if (isTestEnvironment && _database == null) {
      return 0;
    }

    final db = await database;
    final res = await db.rawQuery(
      'SELECT COUNT(*) as total FROM categories WHERE (is_deleted = 0 OR is_deleted IS NULL) AND is_active = 1',
    );
    if (res.isNotEmpty && res.first['total'] != null) {
      return int.tryParse(res.first['total'].toString()) ?? 0;
    }
    return 0;
  }

  /// Close database connection if needed.
  static Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
