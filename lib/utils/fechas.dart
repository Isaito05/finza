DateTime soloFecha(DateTime fecha) =>
    DateTime(fecha.year, fecha.month, fecha.day);

/// Siguiente vencimiento de una factura recurrente.
///
/// Si el día no existe en el mes destino (ej. 31 de enero + 1 mes), se usa
/// el último día de ese mes (28 o 29 de febrero).
DateTime siguienteVencimiento(DateTime fecha, String? frecuencia) {
  switch (frecuencia) {
    case 'Semanal':
      return DateTime(fecha.year, fecha.month, fecha.day + 7);
    case 'Trimestral':
      return _sumarMeses(fecha, 3);
    case 'Anual':
      return _sumarMeses(fecha, 12);
    case 'Mensual':
    default:
      return _sumarMeses(fecha, 1);
  }
}

DateTime _sumarMeses(DateTime fecha, int meses) {
  final totalMeses = fecha.month - 1 + meses;
  final anio = fecha.year + totalMeses ~/ 12;
  final mes = totalMeses % 12 + 1;

  final ultimoDiaDelMes = DateTime(anio, mes + 1, 0).day;
  final dia = fecha.day > ultimoDiaDelMes ? ultimoDiaDelMes : fecha.day;

  return DateTime(anio, mes, dia);
}
