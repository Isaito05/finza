/// Formato colombiano: punto para miles y coma para decimales.
/// Ejemplo: 1500000.5 -> `$1.500.000,50`.
String formatearDinero(double valor) {
  final negativo = valor < 0;
  final partes = valor.abs().toStringAsFixed(2).split('.');

  final enteroFormateado = partes[0].replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (match) => '.',
  );

  return '${negativo ? '-' : ''}\$$enteroFormateado,${partes[1]}';
}

/// `dd/mm/aaaa`.
String formatearFecha(DateTime fecha) {
  return '${fecha.day.toString().padLeft(2, '0')}/'
      '${fecha.month.toString().padLeft(2, '0')}/'
      '${fecha.year}';
}

/// `hh:mm` en formato de 24 horas.
String formatearHora(DateTime fecha) {
  return '${fecha.hour.toString().padLeft(2, '0')}:'
      '${fecha.minute.toString().padLeft(2, '0')}';
}

/// Convierte lo que escribe el usuario en un monto. Acepta `80000`,
/// `80.000`, `80.000,50` y `80000.50`.
double? leerMonto(String texto) {
  var limpio = texto.trim().replaceAll(' ', '').replaceAll('\$', '');
  if (limpio.isEmpty) return null;

  if (limpio.contains(',')) {
    // Formato colombiano: los puntos son miles y la coma es el decimal.
    limpio = limpio.replaceAll('.', '').replaceAll(',', '.');
  } else if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(limpio)) {
    // `80.000` o `1.500.000`: puntos de miles sin decimales.
    limpio = limpio.replaceAll('.', '');
  }

  return double.tryParse(limpio);
}

/// Texto para un monto en un campo editable (sin separador de miles).
String montoParaEditar(double monto) {
  if (monto == monto.roundToDouble()) return monto.toStringAsFixed(0);
  return monto.toStringAsFixed(2).replaceAll('.', ',');
}
