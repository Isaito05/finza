import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/movimiento.dart';
import '../models/factura.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();

  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDB('finza.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE movimientos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tipo TEXT NOT NULL,
        categoria TEXT NOT NULL,
        descripcion TEXT NOT NULL,
        monto REAL NOT NULL,
        fecha TEXT NOT NULL
      )
    ''');

    await db.execute('''
    CREATE TABLE facturas (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    nombre TEXT NOT NULL,
    categoria TEXT NOT NULL,
    monto REAL NOT NULL,
    fechaVencimiento TEXT NOT NULL,
    recurrente INTEGER NOT NULL DEFAULT 0,
    frecuencia TEXT,
    estado TEXT NOT NULL DEFAULT 'Pendiente'
    )
  ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
      CREATE TABLE facturas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        categoria TEXT NOT NULL,
        monto REAL NOT NULL,
        fechaVencimiento TEXT NOT NULL,
        recurrente INTEGER NOT NULL DEFAULT 0,
        frecuencia TEXT,
        estado TEXT NOT NULL DEFAULT 'Pendiente'
      )
    ''');
    }
  }

  Future<int> insertarMovimiento(Movimiento movimiento) async {
    final db = await instance.database;

    return await db.insert('movimientos', movimiento.toMap());
  }

  Future<List<Movimiento>> obtenerMovimientos() async {
    final db = await instance.database;

    final resultado = await db.query('movimientos', orderBy: 'fecha DESC');

    return resultado.map((map) => Movimiento.fromMap(map)).toList();
  }

  Future<int> actualizarMovimiento(Movimiento movimiento) async {
    final db = await instance.database;

    return await db.update(
      'movimientos',
      movimiento.toMap(),
      where: 'id = ?',
      whereArgs: [movimiento.id],
    );
  }

  Future<int> eliminarMovimiento(int id) async {
    final db = await instance.database;

    return await db.delete('movimientos', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> insertarFactura(Factura factura) async {
    final db = await instance.database;

    return await db.insert('facturas', factura.toMap());
  }

  Future<List<Factura>> obtenerFacturas() async {
    final db = await instance.database;

    final resultado = await db.query(
      'facturas',
      orderBy: 'fechaVencimiento ASC',
    );

    return resultado.map((map) => Factura.fromMap(map)).toList();
  }

  Future<int> actualizarFactura(Factura factura) async {
    final db = await instance.database;

    return await db.update(
      'facturas',
      factura.toMap(),
      where: 'id = ?',
      whereArgs: [factura.id],
    );
  }

  Future<int> eliminarFactura(int id) async {
    final db = await instance.database;

    return await db.delete('facturas', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> cerrarBaseDeDatos() async {
    final db = await instance.database;

    await db.close();

    _database = null;
  }
}
