import 'package:flutter/material.dart';

import '../models/categorias.dart';
import '../models/movimiento.dart';
import '../theme/app_theme.dart';
import '../utils/formato.dart';
import 'monto.dart';

/// Fila de un movimiento. La usan Inicio, Movimientos y la Papelera.
class TarjetaMovimiento extends StatelessWidget {
  const TarjetaMovimiento({
    super.key,
    required this.movimiento,
    this.onTap,
    this.trailing,
    this.mostrarFecha = true,
  });

  final Movimiento movimiento;
  final VoidCallback? onTap;

  /// Reemplaza el monto a la derecha (la Papelera pone sus botones acá).
  final Widget? trailing;

  /// En las listas agrupadas por día la fecha ya está en el encabezado.
  final bool mostrarFecha;

  @override
  Widget build(BuildContext context) {
    final colores = ColoresFinza.de(context);
    final colorScheme = Theme.of(context).colorScheme;
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    final color = movimiento.esIngreso ? colores.ingreso : colores.gasto;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radio),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: esOscuro ? 0.20 : 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Categorias.icono(movimiento.categoria), color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      movimiento.descripcion,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      mostrarFecha
                          ? '${movimiento.categoria} • ${formatearFecha(movimiento.fecha)}'
                          : movimiento.categoria,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing ??
                  Text(
                    context.dinero(
                      movimiento.esIngreso ? movimiento.monto : -movimiento.monto,
                      conSigno: true,
                    ),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: color,
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
