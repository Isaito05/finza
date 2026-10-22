import 'package:uuid/uuid.dart';

const _sinCambio = Object();

class Movimiento {
  final int? id;

  /// Identificador estable entre dispositivos (el `id` es solo local).
  final String uuid;
  final String tipo;
  final String categoria;
  final String descripcion;
  final double monto;
  final DateTime fecha;

  /// Última modificación. En la sincronización gana la versión más reciente.
  final DateTime actualizadoEn;

  /// Si no es null, el movimiento está en la papelera.
  final DateTime? eliminadoEn;

  /// Eliminado definitivamente. Se conserva la fila para que el borrado
  /// también llegue a los otros dispositivos al sincronizar.
  final bool purgado;

  Movimiento({
    this.id,
    String? uuid,
    required this.tipo,
    required this.categoria,
    required this.descripcion,
    required this.monto,
    required this.fecha,
    DateTime? actualizadoEn,
    this.eliminadoEn,
    this.purgado = false,
  }) : uuid = uuid ?? const Uuid().v4(),
       actualizadoEn = actualizadoEn ?? DateTime.now();

  bool get esIngreso => tipo == 'Ingreso';

  bool get enPapelera => eliminadoEn != null && !purgado;

  Movimiento copyWith({
    int? id,
    String? tipo,
    String? categoria,
    String? descripcion,
    double? monto,
    DateTime? fecha,
    DateTime? actualizadoEn,
    Object? eliminadoEn = _sinCambio,
    bool? purgado,
  }) {
    return Movimiento(
      id: id ?? this.id,
      uuid: uuid,
      tipo: tipo ?? this.tipo,
      categoria: categoria ?? this.categoria,
      descripcion: descripcion ?? this.descripcion,
      monto: monto ?? this.monto,
      fecha: fecha ?? this.fecha,
      actualizadoEn: actualizadoEn ?? this.actualizadoEn,
      eliminadoEn: identical(eliminadoEn, _sinCambio)
          ? this.eliminadoEn
          : eliminadoEn as DateTime?,
      purgado: purgado ?? this.purgado,
    );
  }

  /// Formato para la base de datos local.
  Map<String, dynamic> toMap() {
    return {'id': id, ...toJson(), 'purgado': purgado ? 1 : 0};
  }

  factory Movimiento.fromMap(Map<String, dynamic> map) {
    return Movimiento.fromJson(map).copyWith(id: map['id'] as int?);
  }

  /// Formato del archivo de sincronización (sin el `id` local).
  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      'tipo': tipo,
      'categoria': categoria,
      'descripcion': descripcion,
      'monto': monto,
      'fecha': fecha.toIso8601String(),
      // En UTC: se comparan entre celulares que pueden tener otra zona
      // horaria o un cambio de horario de verano.
      'actualizadoEn': actualizadoEn.toUtc().toIso8601String(),
      'eliminadoEn': eliminadoEn?.toUtc().toIso8601String(),
      'purgado': purgado,
    };
  }

  factory Movimiento.fromJson(Map<String, dynamic> json) {
    final purgado = json['purgado'];

    return Movimiento(
      uuid: json['uuid'] as String,
      tipo: json['tipo'] as String,
      categoria: json['categoria'] as String,
      descripcion: json['descripcion'] as String,
      monto: (json['monto'] as num).toDouble(),
      fecha: DateTime.parse(json['fecha'] as String),
      actualizadoEn: DateTime.parse(json['actualizadoEn'] as String),
      eliminadoEn: json['eliminadoEn'] == null
          ? null
          : DateTime.parse(json['eliminadoEn'] as String),
      purgado: purgado == true || purgado == 1,
    );
  }
}
