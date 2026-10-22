import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_info.dart';
import 'providers/finanzas_provider.dart';
import 'providers/preferencias_provider.dart';
import 'screens/home_shell.dart';
import 'services/actualizacion_service.dart';
import 'services/recordatorios_service.dart';
import 'services/sync_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppInfo.cargar();
  final prefs = await SharedPreferences.getInstance();

  final finanzas = FinanzasProvider();
  final preferencias = PreferenciasProvider(prefs);
  final sync = SyncService(finanzas, prefs);
  final recordatorios = RecordatoriosService(prefs)
    ..alTocarNotificacion = () =>
        HomeShell.tabIndex.value = HomeShell.tabFacturas;

  // Cada cambio hecho por el usuario se sube a Drive (si hay cuenta).
  finanzas.alModificarLocalmente = sync.programarSincronizacion;

  // Los recordatorios se recalculan cuando cambian las facturas o el ajuste.
  void reprogramarRecordatorios() {
    if (finanzas.cargando) return;
    recordatorios.programar(
      finanzas.facturas,
      activos: preferencias.recordatoriosActivos,
    );
  }

  finanzas.addListener(reprogramarRecordatorios);
  preferencias.addListener(reprogramarRecordatorios);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: finanzas),
        ChangeNotifierProvider.value(value: preferencias),
        ChangeNotifierProvider.value(value: sync),
        Provider.value(value: recordatorios),
        Provider(create: (_) => ActualizacionService(prefs)),
      ],
      child: const FinzaApp(),
    ),
  );

  await recordatorios.inicializar();
  await finanzas.cargar();
  unawaited(sync.inicializar());
}

class FinzaApp extends StatelessWidget {
  const FinzaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Finza',
      theme: AppTheme.claro,
      darkTheme: AppTheme.oscuro,
      themeMode: context.watch<PreferenciasProvider>().modoTema,
      home: const HomeShell(),
    );
  }
}
