import 'package:flutter/material.dart';

import '../models/movimiento.dart';
import '../theme/app_theme.dart';
import '../utils/formato.dart';

/// Fila de un movimiento. La usan Inicio, Movimientos y la Papelera.
class TarjetaMovimiento extends StatelessWidget {
  const TarjetaMovimiento({
    super.key,
    required this.movimiento,
    this.onTap,
    this.trailing,
  });

  final Movimiento movimiento;
  final VoidCallback? onTap;

  /// Reemplaza el monto a la derecha (la Papelera pone sus botones acá).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colores = ColoresFinza.de(context);
    final color = movimiento.esIngreso ? colores.ingreso : colores.gasto;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          foregroundColor: color,
          child: Icon(
            movimiento.esIngreso ? Icons.arrow_downward : Icons.arrow_upward,
          ),
        ),
        title: Text(
          movimiento.descripcion,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${movimiento.categoria} • ${formatearFecha(movimiento.fecha)}',
        ),
        trailing:
            trailing ??
            Text(
              '${movimiento.esIngreso ? '+' : '-'}${formatearDinero(movimiento.monto)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: color,
              ),
            ),
        onTap: onTap,
      ),
    );
  }
}
