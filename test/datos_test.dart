import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:finza/database/database_helper.dart';
import 'package:finza/models/factura.dart';
import 'package:finza/models/movimiento.dart';
import 'package:finza/providers/finanzas_provider.dart';
import 'package:finza/services/drive_api.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:finza/services/sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

late Directory carpeta;

Future<void> usarBaseNueva(String nombre) async {
  await DatabaseHelper.instance.cerrarBaseDeDatos();
  DatabaseHelper.rutaPersonalizada = '${carpeta.path}/$nombre.db';
}

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    carpeta = await Directory.systemTemp.createTemp('finza_test');
  });

  tearDownAll(() => carpeta.delete(recursive: true));

  test('migra una base v2 sin perder datos y les asigna uuid', () async {
    final ruta = '${carpeta.path}/v2.db';
    final v2 = await databaseFactoryFfi.openDatabase(
      ruta,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE movimientos (id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'tipo TEXT NOT NULL, categoria TEXT NOT NULL, descripcion TEXT NOT NULL, '
            'monto REAL NOT NULL, fecha TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE facturas (id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'nombre TEXT NOT NULL, categoria TEXT NOT NULL, monto REAL NOT NULL, '
            'fechaVencimiento TEXT NOT NULL, recurrente INTEGER NOT NULL DEFAULT 0, '
            "frecuencia TEXT, estado TEXT NOT NULL DEFAULT 'Pendiente')",
          );
        },
      ),
    );
    for (final descripcion in ['Almuerzo', 'Bus']) {
      await v2.insert('movimientos', {
        'tipo': 'Gasto',
        'categoria': 'Alimentación',
        'descripcion': descripcion,
        'monto': 15000.0,
        'fecha': DateTime(2026, 9, 1).toIso8601String(),
      });
    }
    await v2.insert('facturas', {
      'nombre': 'Internet',
      'categoria': 'Internet',
      'monto': 80000.0,
      'fechaVencimiento': DateTime(2026, 9, 1).toIso8601String(),
      'recurrente': 1,
      'frecuencia': 'Mensual',
      'estado': 'Pendiente',
    });
    await v2.close();

    await DatabaseHelper.instance.cerrarBaseDeDatos();
    DatabaseHelper.rutaPersonalizada = ruta;

    final movimientos = await DatabaseHelper.instance.obtenerMovimientos();
    final facturas = await DatabaseHelper.instance.obtenerFacturas();

    expect(
      movimientos.map((m) => m.descripcion),
      unorderedEquals(['Almuerzo', 'Bus']),
    );
    expect(movimientos.map((m) => m.uuid).toSet(), hasLength(2));
    expect(facturas.single.recurrente, isTrue);
    expect(facturas.single.eliminadoEn, isNull);
  });

  group('FinanzasProvider', () {
    late FinanzasProvider finanzas;

    setUp(() async {
      await usarBaseNueva('provider_${DateTime.now().microsecondsSinceEpoch}');
      finanzas = FinanzasProvider();
      await finanzas.cargar();
    });

    test('guardar, editar, eliminar a la papelera y restaurar', () async {
      var modificaciones = 0;
      finanzas.alModificarLocalmente = () => modificaciones++;

      await finanzas.guardarMovimiento(
        Movimiento(
          tipo: 'Ingreso',
          categoria: 'Salario',
          descripcion: 'Pago',
          monto: 100,
          fecha: DateTime(2026, 10, 1),
        ),
      );
      final guardado = finanzas.movimientos.single;
      await finanzas.guardarMovimiento(guardado.copyWith(monto: 250));
      expect(finanzas.saldo, 250);

      await finanzas.eliminarMovimiento(finanzas.movimientos.single);
      expect(finanzas.movimientos, isEmpty);
      expect(finanzas.movimientosEnPapelera, hasLength(1));
      expect(finanzas.saldo, 0);

      await finanzas.restaurarMovimiento(finanzas.movimientosEnPapelera.single);
      expect(finanzas.movimientos.single.monto, 250);

      await finanzas.eliminarMovimiento(finanzas.movimientos.single);
      await finanzas.vaciarPapelera();
      expect(finanzas.movimientosEnPapelera, isEmpty);

      expect(modificaciones, 6);
    });

    test('pagar una recurrente crea la siguiente una sola vez', () async {
      await finanzas.guardarFactura(
        Factura(
          nombre: 'Arriendo',
          categoria: 'Vivienda',
          monto: 900000,
          fechaVencimiento: DateTime(2026, 1, 31),
          recurrente: true,
          frecuencia: 'Mensual',
          estado: 'Pendiente',
        ),
      );
      final enero = finanzas.facturas.single;

      final febrero = await finanzas.cambiarEstadoFactura(enero, pagada: true);
      expect(febrero?.fechaVencimiento, DateTime(2026, 2, 28));
      expect(finanzas.facturas, hasLength(2));

      // Desmarcar y volver a pagar no duplica la de febrero.
      final eneroPagada = finanzas.facturas.firstWhere(
        (f) => f.uuid == enero.uuid,
      );
      await finanzas.cambiarEstadoFactura(eneroPagada, pagada: false);
      final eneroPendiente = finanzas.facturas.firstWhere(
        (f) => f.uuid == enero.uuid,
      );
      final otra = await finanzas.cambiarEstadoFactura(
        eneroPendiente,
        pagada: true,
      );
      expect(otra, isNull);
      expect(finanzas.facturas, hasLength(2));
    });
  });

  group('SyncService con un Drive simulado', () {
    late _DriveFalso drive;
    late FinanzasProvider finanzas;
    late SyncService sync;

    setUp(() async {
      await usarBaseNueva('sync_${DateTime.now().microsecondsSinceEpoch}');
      SharedPreferences.setMockInitialValues({});
      drive = _DriveFalso();
      finanzas = FinanzasProvider();
      await finanzas.cargar();
      sync = SyncService(finanzas, await SharedPreferences.getInstance());
    });

    Movimiento gasto(String descripcion) => Movimiento(
      tipo: 'Gasto',
      categoria: 'Transporte',
      descripcion: descripcion,
      monto: 3000,
      fecha: DateTime(2026, 10, 1),
    );

    test('la primera vez crea el archivo con los datos locales', () async {
      await finanzas.guardarMovimiento(gasto('Bus'));
      await sync.sincronizarCon(drive.api);

      final archivo = drive.unicoArchivo;
      expect(archivo['app'], 'finza');
      expect((archivo['movimientos'] as List).single['descripcion'], 'Bus');
    });

    test('combina con lo que subió otro celular y propaga borrados', () async {
      await finanzas.guardarMovimiento(gasto('Bus'));
      await sync.sincronizarCon(drive.api);

      // Otro celular agrega un movimiento y borra "Bus" después.
      final archivo = drive.unicoArchivo;
      final bus =
          (archivo['movimientos'] as List).single as Map<String, dynamic>;
      final despues = DateTime.now()
          .add(const Duration(minutes: 1))
          .toIso8601String();
      archivo['movimientos'] = [
        {...bus, 'eliminadoEn': despues, 'actualizadoEn': despues},
        gasto('Taxi').toJson(),
      ];
      drive.reemplazarUnico(archivo);

      // Y este celular agrega otro sin haber sincronizado.
      await finanzas.guardarMovimiento(gasto('Metro'));
      await sync.sincronizarCon(drive.api);

      expect(
        finanzas.movimientos.map((m) => m.descripcion),
        unorderedEquals(['Taxi', 'Metro']),
      );
      expect(finanzas.movimientosEnPapelera.single.descripcion, 'Bus');

      final subidos = (drive.unicoArchivo['movimientos'] as List).map(
        (m) => m['descripcion'],
      );
      expect(subidos, unorderedEquals(['Bus', 'Taxi', 'Metro']));
    });

    test('si se borró el archivo en Drive, lo vuelve a crear', () async {
      await finanzas.guardarMovimiento(gasto('Bus'));
      await sync.sincronizarCon(drive.api);
      drive.archivos.clear();

      await sync.sincronizarCon(drive.api);
      expect(drive.archivos, hasLength(1));
    });

    test('no pisa un archivo de una versión más nueva de Finza', () async {
      drive.archivos['x'] = jsonEncode({
        'formato': 99,
        'movimientos': [],
        'facturas': [],
      });
      await expectLater(sync.sincronizarCon(drive.api), throwsException);
      expect(jsonDecode(drive.archivos['x']!)['formato'], 99);
    });
  });
  group('sin conexión con Drive', () {
    late _DriveFalso drive;
    late FinanzasProvider finanzas;
    late SyncService sync;
    late StreamController<List<ConnectivityResult>> red;
    late bool hayRed;

    setUp(() async {
      await usarBaseNueva('offline_${DateTime.now().microsecondsSinceEpoch}');
      SharedPreferences.setMockInitialValues({});
      drive = _DriveFalso();
      red = StreamController.broadcast();
      hayRed = true;
      finanzas = FinanzasProvider();
      await finanzas.cargar();
      sync = SyncService(
        finanzas,
        await SharedPreferences.getInstance(),
        clienteHttp: drive.cliente,
        conectividad: red.stream,
        hayRed: () async => hayRed,
      );
      await sync.conectarParaPruebas(() async => 'token');
      finanzas.alModificarLocalmente = sync.programarSincronizacion;
    });

    tearDown(() async {
      sync.dispose();
      await red.close();
    });

    Future<void> esperarEstado(EstadoSync estado) async {
      for (var i = 0; i < 200 && sync.estado != estado; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(sync.estado, estado);
    }

    Movimiento gasto(String descripcion) => Movimiento(
      tipo: 'Gasto',
      categoria: 'Transporte',
      descripcion: descripcion,
      monto: 3000,
      fecha: DateTime(2026, 10, 1),
    );

    test(
      'sin internet la app sigue funcionando y deja el cambio pendiente',
      () async {
        hayRed = false;
        await finanzas.guardarMovimiento(gasto('Bus'));
        await sync.sincronizar();

        expect(sync.estado, EstadoSync.sinConexion);
        expect(sync.hayCambiosPendientes, isTrue);
        expect(sync.proximoReintento, isNotNull);
        expect(finanzas.movimientos.single.descripcion, 'Bus');
        expect(drive.archivos, isEmpty);
      },
    );

    test('con Drive caído, sube lo pendiente apenas vuelve la red', () async {
      drive.fallaCon = 503;
      await finanzas.guardarMovimiento(gasto('Bus'));
      await sync.sincronizar();
      expect(sync.estado, EstadoSync.sinConexion);

      drive.fallaCon = null;
      red.add([ConnectivityResult.wifi]);
      await esperarEstado(EstadoSync.listo);

      expect(sync.hayCambiosPendientes, isFalse);
      expect(sync.proximoReintento, isNull);
      expect(
        (drive.unicoArchivo['movimientos'] as List).single['descripcion'],
        'Bus',
      );
    });

    test('una conexión que se corta a mitad cuenta como temporal', () async {
      drive.sinRed = true;
      await finanzas.guardarMovimiento(gasto('Bus'));
      await sync.sincronizar();
      expect(sync.estado, EstadoSync.sinConexion);
    });

    test('los reintentos se espacian cada vez más', () async {
      hayRed = false;
      final esperas = <int>[];
      for (var i = 0; i < 8; i++) {
        final antes = DateTime.now();
        await sync.sincronizar();
        esperas.add(sync.proximoReintento!.difference(antes).inSeconds);
      }
      expect(esperas, [15, 30, 60, 120, 300, 600, 600, 600]);
    });

    test('un error que no es de conexión no se reintenta solo', () async {
      drive.fallaCon = 403;
      await finanzas.guardarMovimiento(gasto('Bus'));
      await sync.sincronizar();

      expect(sync.estado, EstadoSync.error);
      expect(sync.proximoReintento, isNull);
      expect(sync.hayCambiosPendientes, isTrue);
    });

    test('los pendientes se recuerdan aunque se cierre la app', () async {
      hayRed = false;
      await finanzas.guardarMovimiento(gasto('Bus'));
      await sync.sincronizar();
      sync.dispose();

      // "Se vuelve a abrir la app": nuevo servicio con las mismas preferencias.
      sync = SyncService(
        finanzas,
        await SharedPreferences.getInstance(),
        clienteHttp: drive.cliente,
        hayRed: () async => true,
      );
      expect(sync.vinculado, isTrue);
      expect(sync.hayCambiosPendientes, isTrue);

      await sync.conectarParaPruebas(() async => 'token');
      await sync.sincronizar();
      expect(sync.estado, EstadoSync.listo);
      expect(sync.hayCambiosPendientes, isFalse);
      expect(drive.archivos, hasLength(1));
    });
  });

  test('clasifica qué fallas son temporales', () {
    expect(SyncService.esFallaTemporal(const SocketException('x')), isTrue);
    expect(SyncService.esFallaTemporal(TimeoutException('x')), isTrue);
    expect(SyncService.esFallaTemporal(http.ClientException('x')), isTrue);
    expect(SyncService.esFallaTemporal(DriveException(503, 'x')), isTrue);
    expect(SyncService.esFallaTemporal(DriveException(429, 'x')), isTrue);
    expect(SyncService.esFallaTemporal(DriveException(403, 'x')), isFalse);
    expect(SyncService.esFallaTemporal(Exception('versión nueva')), isFalse);
    expect(
      SyncService.esFallaTemporal(
        const GoogleSignInException(
          code: GoogleSignInExceptionCode.unknownError,
        ),
      ),
      isFalse,
    );
  });

  group('correcciones de la revisión', () {
    late _DriveFalso drive;
    late FinanzasProvider finanzas;
    late SyncService sync;

    setUp(() async {
      await usarBaseNueva('revision_${DateTime.now().microsecondsSinceEpoch}');
      SharedPreferences.setMockInitialValues({});
      drive = _DriveFalso();
      finanzas = FinanzasProvider();
      await finanzas.cargar();
      sync = SyncService(
        finanzas,
        await SharedPreferences.getInstance(),
        clienteHttp: drive.cliente,
        hayRed: () async => true,
      );
      await sync.conectarParaPruebas(() async => 'token');
    });

    tearDown(() => sync.dispose());

    Movimiento gasto(String descripcion) => Movimiento(
      tipo: 'Gasto',
      categoria: 'Transporte',
      descripcion: descripcion,
      monto: 3000,
      fecha: DateTime(2026, 10, 1),
    );

    test('las fechas de sincronización se guardan en UTC', () {
      final json = gasto('Bus').toJson();
      expect(json['actualizadoEn'], endsWith('Z'));
    });

    test('lo que llega de Drive no pisa una edición local más nueva', () async {
      await finanzas.guardarMovimiento(gasto('Bus'));
      final local = finanzas.movimientos.single;
      final viejo = local.copyWith(
        descripcion: 'Versión vieja de Drive',
        actualizadoEn: local.actualizadoEn.subtract(const Duration(minutes: 1)),
      );
      final nuevo = local.copyWith(
        descripcion: 'Versión nueva de Drive',
        actualizadoEn: local.actualizadoEn.add(const Duration(minutes: 1)),
      );

      await DatabaseHelper.instance.aplicarCambiosRemotos(
        movimientos: [viejo],
        facturas: [],
      );
      await finanzas.cargar();
      expect(finanzas.movimientos.single.descripcion, 'Bus');

      await DatabaseHelper.instance.aplicarCambiosRemotos(
        movimientos: [nuevo],
        facturas: [],
      );
      await finanzas.cargar();
      expect(finanzas.movimientos.single.descripcion, 'Versión nueva de Drive');
    });

    test('pagar la misma recurrente en dos celulares no la duplica', () async {
      final arriendo = Factura(
        nombre: 'Arriendo',
        categoria: 'Vivienda',
        monto: 900000,
        fechaVencimiento: DateTime(2026, 3, 5),
        recurrente: true,
        frecuencia: 'Mensual',
        estado: 'Pendiente',
      );

      Future<String> pagarEnOtroCelular(String nombre) async {
        await usarBaseNueva(nombre);
        final celular = FinanzasProvider();
        await celular.guardarFactura(arriendo);
        final siguiente = await celular.cambiarEstadoFactura(
          celular.facturas.single,
          pagada: true,
        );
        return siguiente!.uuid;
      }

      final unix = DateTime.now().microsecondsSinceEpoch;
      final enA = await pagarEnOtroCelular('celular_a_$unix');
      final enB = await pagarEnOtroCelular('celular_b_$unix');
      expect(enA, enB);
    });

    test(
      'dos celulares que crean el archivo a la vez terminan en el mismo',
      () async {
        // El otro celular ya creó su archivo, pero esta búsqueda no lo ve.
        drive.archivos['del_otro_celular'] = jsonEncode({
          'formato': 1,
          'movimientos': [gasto('Taxi').toJson()],
          'facturas': [],
        });
        drive.ocultarEnPrimeraBusqueda = true;

        await finanzas.guardarMovimiento(gasto('Bus'));
        await sync.sincronizarCon(drive.api);

        expect(drive.archivos.keys, ['del_otro_celular']);
        final subidos = (drive.unicoArchivo['movimientos'] as List).map(
          (m) => m['descripcion'],
        );
        expect(subidos, unorderedEquals(['Taxi', 'Bus']));
        expect(
          finanzas.movimientos.map((m) => m.descripcion),
          unorderedEquals(['Taxi', 'Bus']),
        );
      },
    );

    test(
      'desconectar a mitad de una sincronización la deja sin efecto',
      () async {
        await finanzas.guardarMovimiento(gasto('Bus'));
        drive.pausa = Completer();

        final enCurso = sync.sincronizar();
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await sync.desconectar();
        drive.pausa!.complete();
        await enCurso;

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('drive_archivo_id'), isNull);
        expect(sync.vinculado, isFalse);
        expect(sync.estado, isNot(EstadoSync.listo));
      },
    );

    test('la papelera purga sola lo que lleva más de 30 días', () async {
      var modificaciones = 0;
      finanzas.alModificarLocalmente = () => modificaciones++;
      final hace40Dias = DateTime.now().subtract(const Duration(days: 40));

      await DatabaseHelper.instance.insertarMovimiento(
        gasto('Viejo').copyWith(eliminadoEn: hace40Dias),
      );
      await DatabaseHelper.instance.insertarMovimiento(
        gasto('Reciente').copyWith(eliminadoEn: DateTime.now()),
      );
      await finanzas.cargar();

      expect(finanzas.movimientosEnPapelera.single.descripcion, 'Reciente');
      expect(modificaciones, 1);

      // La purga queda en la base para que viaje a los otros celulares.
      final exportado = await DatabaseHelper.instance.exportarParaSincronizar();
      final viejo = exportado['movimientos']!.firstWhere(
        (m) => m['descripcion'] == 'Viejo',
      );
      expect(viejo['purgado'], isTrue);
    });
  });
}

/// Simula la API de Drive en memoria.
class _DriveFalso {
  final archivos = <String, String>{};
  var _siguienteId = 1;

  /// Si no es null, Drive responde con este código a todo (503 = caído).
  int? fallaCon;

  /// Si es true, la conexión se corta antes de llegar a Drive.
  bool sinRed = false;

  /// Simula que otro celular creó su archivo justo después de que este
  /// buscara: la primera búsqueda no lo ve.
  bool ocultarEnPrimeraBusqueda = false;

  /// Si no es null, cada respuesta espera a que se complete.
  Completer<void>? pausa;

  MockClient get cliente => MockClient((solicitud) async {
    if (pausa != null) await pausa!.future;
    if (sinRed) throw http.ClientException('Connection reset');
    if (fallaCon != null) return http.Response('{}', fallaCon!);
    return _responder(solicitud);
  });

  DriveApi get api => DriveApi('token', cliente: cliente);

  Map<String, dynamic> get unicoArchivo =>
      jsonDecode(archivos.values.single) as Map<String, dynamic>;

  void reemplazarUnico(Map<String, dynamic> contenido) {
    archivos[archivos.keys.single] = jsonEncode(contenido);
  }

  Future<http.Response> _responder(http.Request solicitud) async {
    final ruta = solicitud.url.path;

    if (solicitud.method == 'GET' && ruta == '/drive/v3/files') {
      if (ocultarEnPrimeraBusqueda) {
        ocultarEnPrimeraBusqueda = false;
        return http.Response(jsonEncode({'files': []}), 200);
      }
      return http.Response(
        jsonEncode({
          'files': [
            for (final id in archivos.keys) {'id': id},
          ],
        }),
        200,
      );
    }
    if (solicitud.method == 'GET' && ruta.startsWith('/drive/v3/files/')) {
      final contenido = archivos[ruta.split('/').last];
      return contenido == null
          ? http.Response('', 404)
          : http.Response.bytes(utf8.encode(contenido), 200);
    }
    if (solicitud.method == 'POST' && ruta == '/upload/drive/v3/files') {
      final partes = solicitud.body.split('--finza_limite_multipart');
      final contenido = partes[2].split('\r\n\r\n')[1].trim();
      final id = 'archivo${_siguienteId++}';
      archivos[id] = contenido;
      return http.Response(jsonEncode({'id': id}), 200);
    }
    if (solicitud.method == 'PATCH' &&
        ruta.startsWith('/upload/drive/v3/files/')) {
      final id = ruta.split('/').last;
      if (!archivos.containsKey(id)) return http.Response('', 404);
      archivos[id] = solicitud.body;
      return http.Response('{}', 200);
    }
    if (solicitud.method == 'DELETE' && ruta.startsWith('/drive/v3/files/')) {
      archivos.remove(ruta.split('/').last);
      return http.Response('', 204);
    }
    return http.Response('ruta no simulada: ${solicitud.method} $ruta', 500);
  }
}
