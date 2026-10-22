import '../models/factura.dart';
import 'fechas.dart';

enum EstadoFactura { pagada, vencida, venceHoy, proxima, pendiente }

/// Estado que se muestra en la interfaz. Se calcula con la fecha de hoy y no
/// se guarda: en la base solo existen 'Pendiente' y 'Pagada'.
EstadoFactura estadoDeFactura(Factura factura, {DateTime? hoy}) {
  if (factura.pagada) return EstadoFactura.pagada;

  final diferencia = soloFecha(factura.fechaVencimiento)
      .difference(soloFecha(hoy ?? DateTime.now()))
      .inDays;

  if (diferencia < 0) return EstadoFactura.vencida;
  if (diferencia == 0) return EstadoFactura.venceHoy;
  if (diferencia <= 3) return EstadoFactura.proxima;
  return EstadoFactura.pendiente;
}
