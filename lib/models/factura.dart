class Factura {
  final int? id;
  final String nombre;
  final String categoria;
  final double monto;
  final DateTime fechaVencimiento;
  final bool recurrente;
  final String? frecuencia;
  final String estado;

  Factura({
    this.id,
    required this.nombre,
    required this.categoria,
    required this.monto,
    required this.fechaVencimiento,
    required this.recurrente,
    this.frecuencia,
    required this.estado,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'categoria': categoria,
      'monto': monto,
      'fechaVencimiento': fechaVencimiento.toIso8601String(),
      'recurrente': recurrente ? 1 : 0,
      'frecuencia': frecuencia,
      'estado': estado,
    };
  }

  factory Factura.fromMap(Map<String, dynamic> map) {
    return Factura(
      id: map['id'] as int?,
      nombre: map['nombre'] as String,
      categoria: map['categoria'] as String,
      monto: (map['monto'] as num).toDouble(),
      fechaVencimiento:
          DateTime.parse(map['fechaVencimiento'] as String),
      recurrente: (map['recurrente'] as int) == 1,
      frecuencia: map['frecuencia'] as String?,
      estado: map['estado'] as String,
    );
  }
}