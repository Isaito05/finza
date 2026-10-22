import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/filtro_movimientos.dart';

/// Preferencias que se guardan en el teléfono (no se sincronizan con Drive).
class PreferenciasProvider extends ChangeNotifier {
  PreferenciasProvider(this._prefs) {
    _modoTema =
        ThemeMode.values.asNameMap()[_prefs.getString(_claveTema)] ??
        ThemeMode.system;
    _recordatoriosActivos = _prefs.getBool(_claveRecordatorios) ?? true;

    final filtroGuardado = _prefs.getString(_claveFiltro);
    if (filtroGuardado != null) {
      try {
        _filtroMovimientos = FiltroMovimientos.fromJson(
          jsonDecode(filtroGuardado) as Map<String, dynamic>,
        );
      } catch (_) {
        // Si el formato cambió entre versiones, se usa el filtro por defecto.
      }
    }
  }

  static const _claveTema = 'tema';
  static const _claveRecordatorios = 'recordatorios_activos';
  static const _claveFiltro = 'filtro_movimientos';

  final SharedPreferences _prefs;

  SharedPreferences get prefs => _prefs;

  late ThemeMode _modoTema;
  late bool _recordatoriosActivos;
  FiltroMovimientos _filtroMovimientos = const FiltroMovimientos();

  ThemeMode get modoTema => _modoTema;
  bool get recordatoriosActivos => _recordatoriosActivos;
  FiltroMovimientos get filtroMovimientos => _filtroMovimientos;

  set modoTema(ThemeMode modo) {
    _modoTema = modo;
    _prefs.setString(_claveTema, modo.name);
    notifyListeners();
  }

  set recordatoriosActivos(bool activos) {
    _recordatoriosActivos = activos;
    _prefs.setBool(_claveRecordatorios, activos);
    notifyListeners();
  }

  set filtroMovimientos(FiltroMovimientos filtro) {
    _filtroMovimientos = filtro;
    _prefs.setString(_claveFiltro, jsonEncode(filtro.toJson()));
    notifyListeners();
  }
}
