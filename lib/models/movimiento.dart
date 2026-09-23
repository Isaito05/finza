class Movimiento {
  final int? id;
  final String tipo;
  final String categoria;
  final String descripcion;
  final double monto;
  final DateTime fecha;

  Movimiento({
    this.id,
    required this.tipo,
    required this.categoria,
    required this.descripcion,
    required this.monto,
    required this.fecha,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tipo': tipo,
      'categoria': categoria,
      'descripcion': descripcion,
      'monto': monto,
      'fecha': fecha.toIso8601String(),
    };
  }

  factory Movimiento.fromMap(Map<String, dynamic> map) {
    return Movimiento(
      id: map['id'] as int?,
      tipo: map['tipo'] as String,
      categoria: map['categoria'] as String,
      descripcion: map['descripcion'] as String,
      monto: (map['monto'] as num).toDouble(),
      fecha: DateTime.parse(map['fecha'] as String),
    );
  }
}