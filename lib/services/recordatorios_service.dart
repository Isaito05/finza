import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/factura.dart';
import '../utils/fechas.dart';
import '../utils/formato.dart';

/// Recordatorios locales de facturas: el día anterior y el día del
/// vencimiento, a las 9:00. No usan servidor (a diferencia de las push de
/// top-list): Android los dispara aunque la app esté cerrada.
class RecordatoriosService {
  RecordatoriosService(this._prefs);

  static const _canal = AndroidNotificationDetails(
    'facturas',
    'Facturas por vencer',
    channelDescription: 'Recordatorios de facturas pendientes',
    importance: Importance.high,
    priority: Priority.high,
  );
  static const _horaAviso = 9;

  /// Android limita las alarmas por app; con esto sobra.
  static const _maximoAvisos = 60;
  static const _clavePermisoPedido = 'notificaciones_permiso_pedido';

  final SharedPreferences _prefs;
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _listo = false;
  String? _ultimaFirma;
  Timer? _temporizador;

  /// Se llama al tocar una notificación (abre la pestaña de Facturas).
  VoidCallback? alTocarNotificacion;

  Future<void> inicializar() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;

    tz.initializeTimeZones();
    try {
      final zona = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zona.identifier));
    } catch (e) {
      // Algunos teléfonos reportan zonas que no están en la base de datos
      // (ej. "GMT-05:00"). Se queda en UTC: igual funciona, porque cada aviso
      // se programa con el instante exacto (TZDateTime.from).
      debugPrint('Recordatorios: zona horaria desconocida, se usa UTC: $e');
    }

    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          // Ícono monocromo: con el de la app, Android muestra un cuadro blanco.
          android: AndroidInitializationSettings('ic_stat_finza'),
        ),
        onDidReceiveNotificationResponse: (_) => alTocarNotificacion?.call(),
      );

      final lanzamiento = await _plugin.getNotificationAppLaunchDetails();
      if (lanzamiento?.didNotificationLaunchApp ?? false) {
        alTocarNotificacion?.call();
      }

      _listo = true;
    } catch (e) {
      debugPrint('Recordatorios: no se pudieron iniciar: $e');
    }
  }

  /// Reprograma todos los avisos. Se puede llamar seguido: espera un momento
  /// y no hace nada si las facturas pendientes no cambiaron.
  void programar(List<Factura> facturas, {required bool activos}) {
    _temporizador?.cancel();
    _temporizador = Timer(
      const Duration(milliseconds: 500),
      () => _programar(facturas, activos: activos),
    );
  }

  Future<void> _programar(
    List<Factura> facturas, {
    required bool activos,
  }) async {
    if (!_listo) return;

    final avisos = activos ? _calcularAvisos(facturas) : <_Aviso>[];
    final firma = avisos
        .map((a) => '${a.cuando}|${a.titulo}|${a.cuerpo}')
        .join(';');
    if (firma == _ultimaFirma) return;
    _ultimaFirma = firma;

    await _plugin.cancelAll();
    if (avisos.isEmpty) return;

    await _pedirPermisoUnaVez();

    for (var i = 0; i < avisos.length; i++) {
      final aviso = avisos[i];
      await _plugin.zonedSchedule(
        id: i,
        title: aviso.titulo,
        body: aviso.cuerpo,
        scheduledDate: tz.TZDateTime.from(aviso.cuando, tz.local),
        notificationDetails: const NotificationDetails(android: _canal),
        // Inexacto: no necesita el permiso de alarmas exactas y un aviso
        // de factura no tiene que llegar al segundo.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'facturas',
      );
    }
  }

  List<_Aviso> _calcularAvisos(List<Factura> facturas) {
    final ahora = DateTime.now();
    final avisos = <_Aviso>[];

    for (final factura in facturas.where((f) => !f.pagada)) {
      final vence = soloFecha(factura.fechaVencimiento);
      final monto = formatearDinero(factura.monto);

      final diaAntes = vence.subtract(const Duration(days: 1));
      avisos.add(
        _Aviso(
          DateTime(diaAntes.year, diaAntes.month, diaAntes.day, _horaAviso),
          '${factura.nombre} vence mañana',
          'Pago de $monto.',
        ),
      );
      avisos.add(
        _Aviso(
          DateTime(vence.year, vence.month, vence.day, _horaAviso),
          '${factura.nombre} vence hoy',
          'Pago de $monto. Márcala como pagada en Finza.',
        ),
      );
    }

    final futuros = avisos.where((a) => a.cuando.isAfter(ahora)).toList()
      ..sort((a, b) => a.cuando.compareTo(b.cuando));
    return futuros.take(_maximoAvisos).toList();
  }

  /// Android 13+ exige pedir permiso para notificaciones. Se pide la primera
  /// vez que hay algo para avisar, no al abrir la app.
  Future<void> _pedirPermisoUnaVez() async {
    if (_prefs.getBool(_clavePermisoPedido) ?? false) return;
    await _prefs.setBool(_clavePermisoPedido, true);
    await pedirPermiso();
  }

  Future<bool> pedirPermiso() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.requestNotificationsPermission() ?? false;
  }
}

class _Aviso {
  _Aviso(this.cuando, this.titulo, this.cuerpo);

  final DateTime cuando;
  final String titulo;
  final String cuerpo;
}
