import '../utils/fechas.dart';
import 'movimiento.dart';

enum PeriodoFiltro { todo, esteMes, mesPasado, ultimos3Meses, personalizado }

enum OrdenMovimientos { fechaDesc, fechaAsc, montoDesc, montoAsc }

extension PeriodoFiltroTexto on PeriodoFiltro {
  String get etiqueta {
    switch (this) {
      case PeriodoFiltro.todo:
        return 'Todo';
      case PeriodoFiltro.esteMes:
        return 'Este mes';
      case PeriodoFiltro.mesPasado:
        return 'Mes pasado';
      case PeriodoFiltro.ultimos3Meses:
        return 'Últimos 3 meses';
      case PeriodoFiltro.personalizado:
        return 'Personalizado';
    }
  }
}

extension OrdenMovimientosTexto on OrdenMovimientos {
  String get etiqueta {
    switch (this) {
      case OrdenMovimientos.fechaDesc:
        return 'Más recientes';
      case OrdenMovimientos.fechaAsc:
        return 'Más antiguos';
      case OrdenMovimientos.montoDesc:
        return 'Mayor monto';
      case OrdenMovimientos.montoAsc:
        return 'Menor monto';
    }
  }
}

/// Filtros de la pantalla de Movimientos. Se guardan en el teléfono para
/// que se mantengan al cerrar la app.
class FiltroMovimientos {
  final String tipo;
  final PeriodoFiltro periodo;
  final DateTime? desde;
  final DateTime? hasta;

  /// Vacío = todas las categorías.
  final Set<String> categorias;
  final OrdenMovimientos orden;

  const FiltroMovimientos({
    this.tipo = 'Todos',
    this.periodo = PeriodoFiltro.todo,
    this.desde,
    this.hasta,
    this.categorias = const {},
    this.orden = OrdenMovimientos.fechaDesc,
  });

  /// Cantidad de filtros activos del bottom sheet (sin contar el tipo, que
  /// tiene sus propios chips).
  int get activos =>
      (periodo != PeriodoFiltro.todo ? 1 : 0) +
      (categorias.isNotEmpty ? 1 : 0) +
      (orden != OrdenMovimientos.fechaDesc ? 1 : 0);

  FiltroMovimientos copyWith({
    String? tipo,
    PeriodoFiltro? periodo,
    DateTime? desde,
    DateTime? hasta,
    Set<String>? categorias,
    OrdenMovimientos? orden,
  }) {
    return FiltroMovimientos(
      tipo: tipo ?? this.tipo,
      periodo: periodo ?? this.periodo,
      desde: desde ?? this.desde,
      hasta: hasta ?? this.hasta,
      categorias: categorias ?? this.categorias,
      orden: orden ?? this.orden,
    );
  }

  /// Rango [inicio, fin) del periodo, o null si no hay límite.
  ({DateTime inicio, DateTime fin})? rango({DateTime? hoy}) {
    final ahora = hoy ?? DateTime.now();

    switch (periodo) {
      case PeriodoFiltro.todo:
        return null;
      case PeriodoFiltro.esteMes:
        return (
          inicio: DateTime(ahora.year, ahora.month),
          fin: DateTime(ahora.year, ahora.month + 1),
        );
      case PeriodoFiltro.mesPasado:
        return (
          inicio: DateTime(ahora.year, ahora.month - 1),
          fin: DateTime(ahora.year, ahora.month),
        );
      case PeriodoFiltro.ultimos3Meses:
        return (
          inicio: DateTime(ahora.year, ahora.month - 2),
          fin: DateTime(ahora.year, ahora.month + 1),
        );
      case PeriodoFiltro.personalizado:
        if (desde == null || hasta == null) return null;
        return (
          inicio: soloFecha(desde!),
          fin: soloFecha(hasta!).add(const Duration(days: 1)),
        );
    }
  }

  List<Movimiento> aplicar(
    List<Movimiento> movimientos, {
    String busqueda = '',
  }) {
    final texto = busqueda.trim().toLowerCase();
    final limites = rango();

    final resultado = movimientos.where((m) {
      if (tipo != 'Todos' && m.tipo != tipo) return false;
      if (categorias.isNotEmpty && !categorias.contains(m.categoria)) {
        return false;
      }
      if (limites != null &&
          (m.fecha.isBefore(limites.inicio) ||
              !m.fecha.isBefore(limites.fin))) {
        return false;
      }
      if (texto.isNotEmpty &&
          !m.descripcion.toLowerCase().contains(texto) &&
          !m.categoria.toLowerCase().contains(texto)) {
        return false;
      }
      return true;
    }).toList();

    switch (orden) {
      case OrdenMovimientos.fechaDesc:
        resultado.sort((a, b) => b.fecha.compareTo(a.fecha));
      case OrdenMovimientos.fechaAsc:
        resultado.sort((a, b) => a.fecha.compareTo(b.fecha));
      case OrdenMovimientos.montoDesc:
        resultado.sort((a, b) => b.monto.compareTo(a.monto));
      case OrdenMovimientos.montoAsc:
        resultado.sort((a, b) => a.monto.compareTo(b.monto));
    }

    return resultado;
  }

  Map<String, dynamic> toJson() => {
    'tipo': tipo,
    'periodo': periodo.name,
    'desde': desde?.toIso8601String(),
    'hasta': hasta?.toIso8601String(),
    'categorias': categorias.toList(),
    'orden': orden.name,
  };

  factory FiltroMovimientos.fromJson(Map<String, dynamic> json) {
    return FiltroMovimientos(
      tipo: json['tipo'] as String? ?? 'Todos',
      periodo:
          PeriodoFiltro.values.asNameMap()[json['periodo']] ??
          PeriodoFiltro.todo,
      desde: json['desde'] == null ? null : DateTime.parse(json['desde']),
      hasta: json['hasta'] == null ? null : DateTime.parse(json['hasta']),
      categorias: {...(json['categorias'] as List? ?? []).cast<String>()},
      orden:
          OrdenMovimientos.values.asNameMap()[json['orden']] ??
          OrdenMovimientos.fechaDesc,
    );
  }
}
