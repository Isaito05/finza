import 'package:finza/database/database_helper.dart';
import 'package:finza/main.dart';
import 'package:finza/models/factura.dart';
import 'package:finza/models/movimiento.dart';
import 'package:finza/providers/finanzas_provider.dart';
import 'package:finza/providers/preferencias_provider.dart';
import 'package:finza/screens/home_shell.dart';
import 'package:finza/services/actualizacion_service.dart';
import 'package:finza/services/recordatorios_service.dart';
import 'package:finza/services/sync_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Base de datos en memoria, para que los tests de interfaz no dependan de
/// SQLite.
class _BaseEnMemoria implements DatabaseHelper {
  final movimientos = <Movimiento>[];
  final facturas = <Factura>[];
  var _id = 1;

  @override
  Future<int> insertarMovimiento(Movimiento m) async {
    movimientos.add(m.copyWith(id: _id));
    return _id++;
  }

  @override
  Future<int> actualizarMovimiento(Movimiento m) async {
    movimientos[movimientos.indexWhere((x) => x.id == m.id)] = m;
    return 1;
  }

  @override
  Future<List<Movimiento>> obtenerMovimientos() async =>
      movimientos.where((m) => !m.purgado).toList()
        ..sort((a, b) => b.fecha.compareTo(a.fecha));

  @override
  Future<int> insertarFactura(Factura f) async {
    facturas.add(f.copyWith(id: _id));
    return _id++;
  }

  @override
  Future<int> actualizarFactura(Factura f) async {
    facturas[facturas.indexWhere((x) => x.id == f.id)] = f;
    return 1;
  }

  @override
  Future<List<Factura>> obtenerFacturas() async =>
      facturas.where((f) => !f.purgado).toList()
        ..sort((a, b) => a.fechaVencimiento.compareTo(b.fechaVencimiento));

  @override
  Future<bool> existeFactura(String uuid) async =>
      facturas.any((f) => f.uuid == uuid);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<FinanzasProvider> _abrirApp(
  WidgetTester tester, {
  ThemeMode tema = ThemeMode.light,
  void Function(_BaseEnMemoria db)? datos,
}) async {
  SharedPreferences.setMockInitialValues({'tema': tema.name});
  final prefs = await SharedPreferences.getInstance();
  final db = _BaseEnMemoria();
  datos?.call(db);

  final finanzas = FinanzasProvider(db: db);
  await finanzas.cargar();
  HomeShell.tabIndex.value = HomeShell.tabInicio;

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: finanzas),
        ChangeNotifierProvider(create: (_) => PreferenciasProvider(prefs)),
        ChangeNotifierProvider(
          create: (_) => SyncService(finanzas, prefs, db: db),
        ),
        Provider(create: (_) => RecordatoriosService(prefs)),
        Provider(create: (_) => ActualizacionService(prefs)),
      ],
      child: const FinzaApp(),
    ),
  );
  await tester.pumpAndSettle();
  return finanzas;
}

void main() {
  testWidgets('agregar un gasto lo muestra en Inicio y en el saldo', (
    tester,
  ) async {
    final finanzas = await _abrirApp(tester);

    expect(find.text('Todavía no tienes movimientos.'), findsOneWidget);

    await tester.tap(find.text('Agregar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gasto'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Descripción'),
      'Almuerzo',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Monto'), '15.000');
    await tester.tap(find.text('Guardar movimiento'));
    await tester.pumpAndSettle();

    expect(finanzas.movimientos.single.monto, 15000);
    expect(find.text('Almuerzo'), findsOneWidget);
    expect(find.text('-\$15.000,00'), findsWidgets);
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('recorre todas las pestañas en modo oscuro', (tester) async {
    await _abrirApp(
      tester,
      tema: ThemeMode.dark,
      datos: (db) {
        db.movimientos.add(
          Movimiento(
            id: 1,
            tipo: 'Ingreso',
            categoria: 'Salario',
            descripcion: 'Pago',
            monto: 2000000,
            fecha: DateTime.now(),
          ),
        );
        db.facturas.add(
          Factura(
            id: 2,
            nombre: 'Internet',
            categoria: 'Internet',
            monto: 80000,
            fechaVencimiento: DateTime.now().subtract(const Duration(days: 2)),
            recurrente: true,
            frecuencia: 'Mensual',
            estado: 'Pendiente',
          ),
        );
      },
    );

    // Banner de facturas vencidas al abrir.
    expect(find.text('Facturas por pagar'), findsOneWidget);

    for (final pestana in ['Movimientos', 'Estadísticas', 'Facturas']) {
      await tester.tap(find.widgetWithText(NavigationDestination, pestana));
      await tester.pumpAndSettle();
    }
    expect(find.text('Vencida'), findsOneWidget);

    await tester.tap(find.text('Marcar pagada'));
    await tester.pumpAndSettle();
    expect(find.textContaining('La próxima vence el'), findsOneWidget);

    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
  });

  testWidgets('eliminar manda a la papelera y se puede restaurar', (
    tester,
  ) async {
    final finanzas = await _abrirApp(
      tester,
      datos: (db) => db.movimientos.add(
        Movimiento(
          id: 1,
          tipo: 'Gasto',
          categoria: 'Transporte',
          descripcion: 'Bus',
          monto: 3000,
          fecha: DateTime.now(),
        ),
      ),
    );

    await tester.tap(find.text('Bus'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar movimiento'));
    await tester.pumpAndSettle();
    expect(finanzas.movimientos, isEmpty);

    await tester.tap(find.byTooltip('Ajustes'));
    await tester.pumpAndSettle();
    expect(find.text('No disponible en esta versión'), findsOneWidget);

    await tester.tap(find.text('Papelera'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restaurar'));
    await tester.pumpAndSettle();

    expect(finanzas.movimientos.single.descripcion, 'Bus');
    expect(find.text('La papelera está vacía'), findsOneWidget);
    await tester.pump(const Duration(seconds: 10));
  });
}
