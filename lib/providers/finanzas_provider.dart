import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../database/database_helper.dart';
import '../models/factura.dart';
import '../models/movimiento.dart';
import '../utils/fechas.dart';

/// Estado compartido de la app: movimientos y facturas.
///
/// Todas las pantallas leen de acá (con `context.watch<FinanzasProvider>()`)
/// y todos los cambios pasan por acá, así las pestañas siempre muestran lo
/// mismo y no hay que acordarse de recargar después de guardar.
class FinanzasProvider extends ChangeNotifier {
  FinanzasProvider({DatabaseHelper? db}) : _db = db ?? DatabaseHelper.instance;

  final DatabaseHelper _db;

  /// Días que algo queda en la papelera antes de dejar de mostrarse.
  static const diasEnPapelera = 30;

  List<Movimiento> _todosLosMovimientos = [];
  List<Factura> _todasLasFacturas = [];
  bool cargando = true;

  /// Se llama después de cada cambio hecho por el usuario (no después de
  /// aplicar datos que llegaron de Drive). Lo usa la sincronización.
  VoidCallback? alModificarLocalmente;

  List<Movimiento> get movimientos =>
      _todosLosMovimientos.where((m) => m.eliminadoEn == null).toList();

  List<Factura> get facturas =>
      _todasLasFacturas.where((f) => f.eliminadoEn == null).toList();

  List<Movimiento> get movimientosEnPapelera =>
      _todosLosMovimientos
          .where((m) => m.enPapelera && _sigueEnPapelera(m.eliminadoEn!))
          .toList()
        ..sort((a, b) => b.eliminadoEn!.compareTo(a.eliminadoEn!));

  List<Factura> get facturasEnPapelera =>
      _todasLasFacturas
          .where((f) => f.enPapelera && _sigueEnPapelera(f.eliminadoEn!))
          .toList()
        ..sort((a, b) => b.eliminadoEn!.compareTo(a.eliminadoEn!));

  bool _sigueEnPapelera(DateTime eliminadoEn) =>
      DateTime.now().difference(eliminadoEn).inDays < diasEnPapelera;

  double get totalIngresos => movimientos
      .where((m) => m.esIngreso)
      .fold(0, (total, m) => total + m.monto);

  double get totalGastos => movimientos
      .where((m) => !m.esIngreso)
      .fold(0, (total, m) => total + m.monto);

  double get saldo => totalIngresos - totalGastos;

  Future<void> cargar() async {
    _todosLosMovimientos = await _db.obtenerMovimientos();
    _todasLasFacturas = await _db.obtenerFacturas();

    if (await _purgarVencidos()) {
      _todosLosMovimientos = await _db.obtenerMovimientos();
      _todasLasFacturas = await _db.obtenerFacturas();
      alModificarLocalmente?.call();
    }

    cargando = false;
    notifyListeners();
  }

  /// Elimina definitivamente lo que lleva más de [diasEnPapelera] días en
  /// la papelera. Se marca como purgado (no se borra la fila) para que
  /// también desaparezca en los otros celulares.
  Future<bool> _purgarVencidos() async {
    final ahora = DateTime.now();
    var hubo = false;

    for (final m in _todosLosMovimientos) {
      if (m.enPapelera && !_sigueEnPapelera(m.eliminadoEn!)) {
        await _db.actualizarMovimiento(
          m.copyWith(purgado: true, actualizadoEn: ahora),
        );
        hubo = true;
      }
    }
    for (final f in _todasLasFacturas) {
      if (f.enPapelera && !_sigueEnPapelera(f.eliminadoEn!)) {
        await _db.actualizarFactura(
          f.copyWith(purgado: true, actualizadoEn: ahora),
        );
        hubo = true;
      }
    }
    return hubo;
  }

  Future<void> _modificado() async {
    await cargar();
    alModificarLocalmente?.call();
  }

  // ---------- Movimientos ----------

  Future<void> guardarMovimiento(Movimiento movimiento) async {
    final conFecha = movimiento.copyWith(actualizadoEn: DateTime.now());

    if (movimiento.id == null) {
      await _db.insertarMovimiento(conFecha);
    } else {
      await _db.actualizarMovimiento(conFecha);
    }
    await _modificado();
  }

  Future<void> eliminarMovimiento(Movimiento movimiento) async {
    final ahora = DateTime.now();
    await _db.actualizarMovimiento(
      movimiento.copyWith(eliminadoEn: ahora, actualizadoEn: ahora),
    );
    await _modificado();
  }

  Future<void> restaurarMovimiento(Movimiento movimiento) async {
    await _db.actualizarMovimiento(
      movimiento.copyWith(eliminadoEn: null, actualizadoEn: DateTime.now()),
    );
    await _modificado();
  }

  // ---------- Facturas ----------

  Future<void> guardarFactura(Factura factura) async {
    final conFecha = factura.copyWith(actualizadoEn: DateTime.now());

    if (factura.id == null) {
      await _db.insertarFactura(conFecha);
    } else {
      await _db.actualizarFactura(conFecha);
    }
    await _modificado();
  }

  /// Marca la factura como pagada o pendiente. Si se paga una recurrente,
  /// crea la del siguiente periodo y la devuelve (para avisarle al usuario).
  Future<Factura?> cambiarEstadoFactura(
    Factura factura, {
    required bool pagada,
  }) async {
    await _db.actualizarFactura(
      factura.copyWith(
        estado: pagada ? 'Pagada' : 'Pendiente',
        actualizadoEn: DateTime.now(),
      ),
    );

    Factura? siguiente;
    if (pagada && factura.recurrente) {
      siguiente = await _crearSiguienteFactura(factura);
    }

    await _modificado();
    return siguiente;
  }

  Future<Factura?> _crearSiguienteFactura(Factura factura) async {
    final fecha = siguienteVencimiento(
      factura.fechaVencimiento,
      factura.frecuencia,
    );

    // El uuid se deriva de la factura pagada y la fecha: si se paga la misma
    // factura en dos celulares antes de sincronizar, los dos crean el mismo
    // registro y al combinar queda uno solo.
    final uuid = const Uuid().v5(
      Namespace.url.value,
      'finza:siguiente:${factura.uuid}:${soloFecha(fecha).toIso8601String()}',
    );

    // Si se desmarca y se vuelve a marcar como pagada, no se duplica (ni se
    // recrea si el usuario la eliminó).
    final yaExiste =
        await _db.existeFactura(uuid) ||
        facturas.any(
          (f) =>
              f.nombre == factura.nombre &&
              soloFecha(f.fechaVencimiento) == soloFecha(fecha),
        );
    if (yaExiste) return null;

    final siguiente = Factura(
      uuid: uuid,
      nombre: factura.nombre,
      categoria: factura.categoria,
      monto: factura.monto,
      fechaVencimiento: fecha,
      recurrente: true,
      frecuencia: factura.frecuencia,
      estado: 'Pendiente',
    );
    await _db.insertarFactura(siguiente);
    return siguiente;
  }

  Future<void> eliminarFactura(Factura factura) async {
    final ahora = DateTime.now();
    await _db.actualizarFactura(
      factura.copyWith(eliminadoEn: ahora, actualizadoEn: ahora),
    );
    await _modificado();
  }

  Future<void> restaurarFactura(Factura factura) async {
    await _db.actualizarFactura(
      factura.copyWith(eliminadoEn: null, actualizadoEn: DateTime.now()),
    );
    await _modificado();
  }

  // ---------- Papelera ----------

  Future<void> eliminarDefinitivamenteMovimiento(Movimiento movimiento) async {
    await _db.actualizarMovimiento(
      movimiento.copyWith(purgado: true, actualizadoEn: DateTime.now()),
    );
    await _modificado();
  }

  Future<void> eliminarDefinitivamenteFactura(Factura factura) async {
    await _db.actualizarFactura(
      factura.copyWith(purgado: true, actualizadoEn: DateTime.now()),
    );
    await _modificado();
  }

  Future<void> vaciarPapelera() async {
    final ahora = DateTime.now();

    for (final movimiento in movimientosEnPapelera) {
      await _db.actualizarMovimiento(
        movimiento.copyWith(purgado: true, actualizadoEn: ahora),
      );
    }
    for (final factura in facturasEnPapelera) {
      await _db.actualizarFactura(
        factura.copyWith(purgado: true, actualizadoEn: ahora),
      );
    }
    await _modificado();
  }
}
