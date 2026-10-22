import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../models/movimiento.dart';
import '../models/factura.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();

  static Database? _database;

  /// Permite a los tests usar otra ruta (por ejemplo, `inMemoryDatabasePath`).
  @visibleForTesting
  static String? rutaPersonalizada;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDB('finza.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final path = rutaPersonalizada ?? join(await getDatabasesPath(), filePath);

    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE movimientos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL,
        tipo TEXT NOT NULL,
        categoria TEXT NOT NULL,
        descripcion TEXT NOT NULL,
        monto REAL NOT NULL,
        fecha TEXT NOT NULL,
        actualizadoEn TEXT NOT NULL,
        eliminadoEn TEXT,
        purgado INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE facturas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL,
        nombre TEXT NOT NULL,
        categoria TEXT NOT NULL,
        monto REAL NOT NULL,
        fechaVencimiento TEXT NOT NULL,
        recurrente INTEGER NOT NULL DEFAULT 0,
        frecuencia TEXT,
        estado TEXT NOT NULL DEFAULT 'Pendiente',
        actualizadoEn TEXT NOT NULL,
        eliminadoEn TEXT,
        purgado INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await _crearIndices(db);
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

    // Versión 3: campos para sincronizar con Drive y para la papelera.
    if (oldVersion < 3) {
      final ahora = DateTime.now().toUtc().toIso8601String();

      for (final tabla in ['movimientos', 'facturas']) {
        await db.execute('ALTER TABLE $tabla ADD COLUMN uuid TEXT');
        await db.execute('ALTER TABLE $tabla ADD COLUMN actualizadoEn TEXT');
        await db.execute('ALTER TABLE $tabla ADD COLUMN eliminadoEn TEXT');
        await db.execute(
          'ALTER TABLE $tabla ADD COLUMN purgado INTEGER NOT NULL DEFAULT 0',
        );

        final filas = await db.query(tabla, columns: ['id']);
        for (final fila in filas) {
          await db.update(
            tabla,
            {'uuid': const Uuid().v4(), 'actualizadoEn': ahora},
            where: 'id = ?',
            whereArgs: [fila['id']],
          );
        }
      }

      await _crearIndices(db);
    }
  }

  Future<void> _crearIndices(Database db) async {
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_movimientos_uuid ON movimientos(uuid)',
    );
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_facturas_uuid ON facturas(uuid)',
    );
  }

  // ---------- Movimientos ----------

  Future<int> insertarMovimiento(Movimiento movimiento) async {
    final db = await instance.database;

    final datos = movimiento.toMap()..remove('id');
    return await db.insert('movimientos', datos);
  }

  /// Todos los movimientos que no se eliminaron definitivamente, incluidos
  /// los de la papelera.
  Future<List<Movimiento>> obtenerMovimientos() async {
    final db = await instance.database;

    final resultado = await db.query(
      'movimientos',
      where: 'purgado = 0',
      orderBy: 'fecha DESC',
    );

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

  // ---------- Facturas ----------

  Future<int> insertarFactura(Factura factura) async {
    final db = await instance.database;

    final datos = factura.toMap()..remove('id');
    return await db.insert('facturas', datos);
  }

  /// Todas las facturas que no se eliminaron definitivamente, incluidas
  /// las de la papelera.
  Future<List<Factura>> obtenerFacturas() async {
    final db = await instance.database;

    final resultado = await db.query(
      'facturas',
      where: 'purgado = 0',
      orderBy: 'fechaVencimiento ASC',
    );

    return resultado.map((map) => Factura.fromMap(map)).toList();
  }

  /// Si existe una factura con ese uuid, incluidas las eliminadas.
  Future<bool> existeFactura(String uuid) async {
    final db = await instance.database;

    final resultado = await db.query(
      'facturas',
      columns: ['id'],
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
    return resultado.isNotEmpty;
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

  // ---------- Sincronización ----------

  /// Todas las filas en formato de sincronización, incluidas las purgadas
  /// (son las que avisan a los otros dispositivos que algo se borró).
  Future<Map<String, List<Map<String, dynamic>>>>
  exportarParaSincronizar() async {
    final db = await instance.database;

    final movimientos = await db.query('movimientos');
    final facturas = await db.query('facturas');

    return {
      'movimientos': movimientos
          .map((map) => Movimiento.fromMap(map).toJson())
          .toList(),
      'facturas': facturas.map((map) => Factura.fromMap(map).toJson()).toList(),
    };
  }

  /// Inserta o reemplaza por `uuid` las versiones que llegaron de Drive.
  Future<void> aplicarCambiosRemotos({
    required List<Movimiento> movimientos,
    required List<Factura> facturas,
  }) async {
    final db = await instance.database;

    await db.transaction((txn) async {
      for (final movimiento in movimientos) {
        await _guardarPorUuid(txn, 'movimientos', movimiento.toMap());
      }
      for (final factura in facturas) {
        await _guardarPorUuid(txn, 'facturas', factura.toMap());
      }
    });
  }

  Future<void> _guardarPorUuid(
    Transaction txn,
    String tabla,
    Map<String, dynamic> datos,
  ) async {
    datos.remove('id');

    final actual = await txn.query(
      tabla,
      columns: ['actualizadoEn'],
      where: 'uuid = ?',
      whereArgs: [datos['uuid']],
    );

    if (actual.isEmpty) {
      await txn.insert(tabla, datos);
      return;
    }

    // Si el usuario editó el registro mientras se descargaba el archivo de
    // Drive, la versión local es más nueva y no se pisa (se sube en la
    // próxima sincronización).
    final local = DateTime.parse(actual.first['actualizadoEn'] as String);
    final remoto = DateTime.parse(datos['actualizadoEn'] as String);
    if (!remoto.isAfter(local)) return;

    await txn.update(
      tabla,
      datos,
      where: 'uuid = ?',
      whereArgs: [datos['uuid']],
    );
  }

  Future<void> cerrarBaseDeDatos() async {
    final db = await instance.database;

    await db.close();

    _database = null;
  }
}
