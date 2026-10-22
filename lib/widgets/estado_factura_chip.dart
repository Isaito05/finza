import 'package:flutter/material.dart';

import '../models/factura.dart';
import '../theme/app_theme.dart';
import '../utils/estado_factura.dart';

extension EstadoFacturaVisual on EstadoFactura {
  String get texto {
    switch (this) {
      case EstadoFactura.pagada:
        return 'Pagada';
      case EstadoFactura.vencida:
        return 'Vencida';
      case EstadoFactura.venceHoy:
        return 'Vence hoy';
      case EstadoFactura.proxima:
        return 'Próxima a vencer';
      case EstadoFactura.pendiente:
        return 'Pendiente';
    }
  }

  IconData get icono {
    switch (this) {
      case EstadoFactura.pagada:
        return Icons.check_circle;
      case EstadoFactura.vencida:
        return Icons.warning_amber_rounded;
      case EstadoFactura.venceHoy:
        return Icons.today;
      case EstadoFactura.proxima:
        return Icons.schedule;
      case EstadoFactura.pendiente:
        return Icons.pending_outlined;
    }
  }

  Color color(BuildContext context) {
    final colores = ColoresFinza.de(context);
    switch (this) {
      case EstadoFactura.pagada:
        return colores.ingreso;
      case EstadoFactura.venceHoy:
      case EstadoFactura.proxima:
        return colores.alerta;
      case EstadoFactura.vencida:
      case EstadoFactura.pendiente:
        return colores.gasto;
    }
  }
}

/// Chip con el estado de la factura. Al tocarlo abre un selector para
/// cambiarlo entre Pendiente y Pagada (como el `StatusChip` de top-list).
class EstadoFacturaChip extends StatelessWidget {
  const EstadoFacturaChip({
    super.key,
    required this.factura,
    required this.onCambiar,
  });

  final Factura factura;

  /// Recibe `true` si se marcó como pagada.
  final ValueChanged<bool> onCambiar;

  @override
  Widget build(BuildContext context) {
    final estado = estadoDeFactura(factura);
    final color = estado.color(context);

    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _abrirSelector(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(estado.icono, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                estado.texto,
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
              Icon(Icons.arrow_drop_down, size: 18, color: color),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _abrirSelector(BuildContext context) async {
    final pagada = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.pending_outlined),
                title: const Text('Pendiente'),
                trailing: factura.pagada ? null : const Icon(Icons.check),
                onTap: () => Navigator.pop(context, false),
              ),
              ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: const Text('Pagada'),
                subtitle: factura.recurrente && !factura.pagada
                    ? const Text('Se crea la factura del siguiente periodo')
                    : null,
                trailing: factura.pagada ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(context, true),
              ),
            ],
          ),
        );
      },
    );

    if (pagada != null && pagada != factura.pagada) {
      onCambiar(pagada);
    }
  }
}
