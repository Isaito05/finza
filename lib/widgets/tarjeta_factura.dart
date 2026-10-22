import 'package:flutter/material.dart';

import '../models/factura.dart';
import '../utils/estado_factura.dart';
import '../utils/formato.dart';
import 'estado_factura_chip.dart';

class TarjetaFactura extends StatelessWidget {
  const TarjetaFactura({
    super.key,
    required this.factura,
    required this.onCambiarEstado,
    this.onTap,
  });

  final Factura factura;
  final ValueChanged<bool> onCambiarEstado;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final estado = estadoDeFactura(factura);
    final color = estado.color(context);
    final colorTexto = Theme.of(context).colorScheme.onSurfaceVariant;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.15),
                    child: Icon(estado.icono, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          factura.nombre,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(factura.categoria),
                      ],
                    ),
                  ),
                  Text(
                    formatearDinero(factura.monto),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(Icons.calendar_month, size: 18, color: colorTexto),
                  const SizedBox(width: 6),
                  Text('Vence: ${formatearFecha(factura.fechaVencimiento)}'),
                ],
              ),
              if (factura.recurrente) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.repeat, size: 18, color: colorTexto),
                    const SizedBox(width: 6),
                    Text('Pago ${factura.frecuencia?.toLowerCase() ?? ''}'),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  EstadoFacturaChip(
                    factura: factura,
                    onCambiar: onCambiarEstado,
                  ),
                  if (!factura.pagada)
                    OutlinedButton.icon(
                      onPressed: () => onCambiarEstado(true),
                      icon: const Icon(Icons.check),
                      label: const Text('Marcar pagada'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
