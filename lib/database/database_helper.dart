import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    // Menggunakan nama file database yang berbeda untuk memastikan skema baru dibuat
    String path = join(documentsDirectory.path, 'kasir_pro_v2.db');
    return await openDatabase(
      path,
      version: 1, // Versi bisa tetap 1 karena kita ganti nama file
      onCreate: _onCreate,
    );
  }

  // Fungsi ini akan membuat semua tabel saat database pertama kali dibuat
  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE kategori (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nama TEXT NOT NULL UNIQUE
      )
    ''');

    await db.execute('''
      CREATE TABLE produk (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nama TEXT NOT NULL,
        harga REAL NOT NULL,
        stok INTEGER NOT NULL,
        kategori_id INTEGER,
        FOREIGN KEY (kategori_id) REFERENCES kategori(id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE transaksi (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp TEXT NOT NULL,
        total REAL NOT NULL,
        metode_pembayaran TEXT NOT NULL,
        diskon REAL DEFAULT 0,
        pajak REAL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE item_transaksi (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaksi_id INTEGER NOT NULL,
        produk_id INTEGER,
        nama_produk TEXT NOT NULL,
        harga REAL NOT NULL,
        jumlah INTEGER NOT NULL,
        is_quick_sale INTEGER DEFAULT 0,
        FOREIGN KEY (transaksi_id) REFERENCES transaksi(id) ON DELETE CASCADE,
        FOREIGN KEY (produk_id) REFERENCES produk(id) ON DELETE SET NULL
      )
    ''');
    
    await db.execute('''
      CREATE TABLE pengaturan (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
    
    // --- PENGATURAN DEFAULT DIPERBARUI ---
    await db.insert('pengaturan', {'key': 'nama_toko', 'value': 'Toko Anda'});
    await db.insert('pengaturan', {'key': 'alamat_toko', 'value': 'Alamat Toko Anda'});
    await db.insert('pengaturan', {'key': 'logo_path', 'value': ''});
    await db.insert('pengaturan', {'key': 'diskon_default', 'value': '0'});
    await db.insert('pengaturan', {'key': 'pajak_default', 'value': '0'});
    await db.insert('pengaturan', {'key': 'izinkan_stok_kosong', 'value': 'false'});

    // Pengaturan Printer Baru
    await db.insert('pengaturan', {'key': 'printer_type', 'value': 'none'}); // 'none', 'bluetooth', 'usb'
    await db.insert('pengaturan', {'key': 'bt_printer_address', 'value': ''});
    await db.insert('pengaturan', {'key': 'bt_printer_name', 'value': ''});
    await db.insert('pengaturan', {'key': 'usb_vendor_id', 'value': ''});
    await db.insert('pengaturan', {'key': 'usb_product_id', 'value': ''});
    await db.insert('pengaturan', {'key': 'usb_printer_name', 'value': ''});
  }
  
  // --- CRUD Kategori ---
  Future<int> insertKategori(Map<String, dynamic> row) async {
    Database db = await database;
    return await db.insert('kategori', row, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<List<Map<String, dynamic>>> getKategori() async {
    Database db = await database;
    return await db.query('kategori', orderBy: 'nama');
  }

  Future<int> updateKategori(Map<String, dynamic> row) async {
    Database db = await database;
    int id = row['id'];
    return await db.update('kategori', row, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteKategori(int id) async {
    Database db = await database;
    return await db.delete('kategori', where: 'id = ?', whereArgs: [id]);
  }

  // --- CRUD Produk ---
  Future<int> insertProduk(Map<String, dynamic> row) async {
    Database db = await database;
    return await db.insert('produk', row);
  }

  Future<List<Map<String, dynamic>>> getProduk({int? kategoriId}) async {
    Database db = await database;
    if (kategoriId != null) {
      return await db.query('produk', where: 'kategori_id = ?', whereArgs: [kategoriId], orderBy: 'nama');
    }
    return await db.query('produk', orderBy: 'nama');
  }
  
  Future<int> updateProduk(Map<String, dynamic> row) async {
    Database db = await database;
    int id = row['id'];
    return await db.update('produk', row, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteProduk(int id) async {
    Database db = await database;
    return await db.delete('produk', where: 'id = ?', whereArgs: [id]);
  }

  // --- Transaksi ---
  Future<int> simpanTransaksi(Map<String, dynamic> transaksi, List<Map<String, dynamic>> items) async {
    Database db = await database;
    return await db.transaction((txn) async {
      int transaksiId = await txn.insert('transaksi', transaksi);

      for (var item in items) {
        item['transaksi_id'] = transaksiId;
        await txn.insert('item_transaksi', item);

        if (item['produk_id'] != null) {
          await txn.rawUpdate(
            'UPDATE produk SET stok = stok - ? WHERE id = ?',
            [item['jumlah'], item['produk_id']],
          );
        }
      }
      return transaksiId;
    });
  }

  // --- Laporan ---
  Future<List<Map<String, dynamic>>> getLaporan(String tglAwalIso, String tglAkhirIso) async {
    Database db = await database;
    // --- QUERY DIPERBAIKI ---
    final String query = '''
      SELECT
        t.id AS transaksi_id,
        t.timestamp,
        t.total,
        t.metode_pembayaran,
        t.diskon,
        t.pajak,
        it.nama_produk,
        it.harga AS harga_item,
        it.jumlah,
        it.is_quick_sale,
        k.nama AS nama_kategori
      FROM transaksi t
      JOIN item_transaksi it ON t.id = it.transaksi_id
      LEFT JOIN produk p ON it.produk_id = p.id
      LEFT JOIN kategori k ON p.kategori_id = k.id
      WHERE t.timestamp BETWEEN ? AND ?
      ORDER BY t.timestamp DESC
    ''';
    return await db.rawQuery(query, [tglAwalIso, tglAkhirIso]);
  }

  // --- Pengaturan ---
  Future<Map<String, String>> getPengaturan() async {
    Database db = await database;
    List<Map<String, dynamic>> results = await db.query('pengaturan');
    return {for (var item in results) item['key']: item['value'] ?? ''};
  }

  Future<void> updatePengaturan(String key, String value) async {
    Database db = await database;
    await db.update(
      'pengaturan',
      {'value': value},
      where: 'key = ?',
      whereArgs: [key],
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
