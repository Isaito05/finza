import 'package:uuid/uuid.dart';

const _sinCambio = Object();

class Factura {
  final int? id;

  /// Identificador estable entre dispositivos (el `id` es solo local).
  final String uuid;
  final String nombre;
  final String categoria;
  final double monto;
  final DateTime fechaVencimiento;
  final bool recurrente;
  final String? frecuencia;

  /// 'Pendiente' o 'Pagada'. Vencida, Vence hoy y Próxima se calculan
  /// según la fecha (ver `utils/estado_factura.dart`).
  final String estado;

  /// Última modificación. En la sincronización gana la versión más reciente.
  final DateTime actualizadoEn;

  /// Si no es null, la factura está en la papelera.
  final DateTime? eliminadoEn;

  /// Eliminada definitivamente. Se conserva la fila para que el borrado
  /// también llegue a los otros dispositivos al sincronizar.
  final bool purgado;

  Factura({
    this.id,
    String? uuid,
    required this.nombre,
    required this.categoria,
    required this.monto,
    required this.fechaVencimiento,
    required this.recurrente,
    this.frecuencia,
    required this.estado,
    DateTime? actualizadoEn,
    this.eliminadoEn,
    this.purgado = false,
  }) : uuid = uuid ?? const Uuid().v4(),
       actualizadoEn = actualizadoEn ?? DateTime.now();

  bool get pagada => estado == 'Pagada';

  bool get enPapelera => eliminadoEn != null && !purgado;

  Factura copyWith({
    int? id,
    String? uuid,
    String? nombre,
    String? categoria,
    double? monto,
    DateTime? fechaVencimiento,
    bool? recurrente,
    Object? frecuencia = _sinCambio,
    String? estado,
    DateTime? actualizadoEn,
    Object? eliminadoEn = _sinCambio,
    bool? purgado,
  }) {
    return Factura(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      nombre: nombre ?? this.nombre,
      categoria: categoria ?? this.categoria,
      monto: monto ?? this.monto,
      fechaVencimiento: fechaVencimiento ?? this.fechaVencimiento,
      recurrente: recurrente ?? this.recurrente,
      frecuencia: identical(frecuencia, _sinCambio)
          ? this.frecuencia
          : frecuencia as String?,
      estado: estado ?? this.estado,
      actualizadoEn: actualizadoEn ?? this.actualizadoEn,
      eliminadoEn: identical(eliminadoEn, _sinCambio)
          ? this.eliminadoEn
          : eliminadoEn as DateTime?,
      purgado: purgado ?? this.purgado,
    );
  }

  /// Formato para la base de datos local.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      ...toJson(),
      'recurrente': recurrente ? 1 : 0,
      'purgado': purgado ? 1 : 0,
    };
  }

  factory Factura.fromMap(Map<String, dynamic> map) {
    return Factura.fromJson(map).copyWith(id: map['id'] as int?);
  }

  /// Formato del archivo de sincronización (sin el `id` local).
  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      'nombre': nombre,
      'categoria': categoria,
      'monto': monto,
      'fechaVencimiento': fechaVencimiento.toIso8601String(),
      'recurrente': recurrente,
      'frecuencia': frecuencia,
      'estado': estado,
      // En UTC: se comparan entre celulares que pueden tener otra zona
      // horaria o un cambio de horario de verano.
      'actualizadoEn': actualizadoEn.toUtc().toIso8601String(),
      'eliminadoEn': eliminadoEn?.toUtc().toIso8601String(),
      'purgado': purgado,
    };
  }

  factory Factura.fromJson(Map<String, dynamic> json) {
    final recurrente = json['recurrente'];
    final purgado = json['purgado'];

    return Factura(
      uuid: json['uuid'] as String,
      nombre: json['nombre'] as String,
      categoria: json['categoria'] as String,
      monto: (json['monto'] as num).toDouble(),
      fechaVencimiento: DateTime.parse(json['fechaVencimiento'] as String),
      recurrente: recurrente == true || recurrente == 1,
      frecuencia: json['frecuencia'] as String?,
      estado: json['estado'] as String,
      actualizadoEn: DateTime.parse(json['actualizadoEn'] as String),
      eliminadoEn: json['eliminadoEn'] == null
          ? null
          : DateTime.parse(json['eliminadoEn'] as String),
      purgado: purgado == true || purgado == 1,
    );
  }
}
