import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/formato.dart';

/// Tarjeta de total de ingresos o de gastos (Inicio y Estadísticas).
class TarjetaResumen extends StatelessWidget {
  const TarjetaResumen({
    super.key,
    required this.esIngreso,
    required this.valor,
    this.centrada = false,
  });

  final bool esIngreso;
  final double valor;
  final bool centrada;

  @override
  Widget build(BuildContext context) {
    final colores = ColoresFinza.de(context);
    final color = esIngreso ? colores.ingreso : colores.gasto;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: centrada
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            Icon(
              esIngreso ? Icons.arrow_downward : Icons.arrow_upward,
              color: color,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              esIngreso ? 'Ingresos' : 'Gastos',
              style: TextStyle(fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                formatearDinero(valor),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta grande del saldo.
class TarjetaSaldo extends StatelessWidget {
  const TarjetaSaldo({
    super.key,
    required this.saldo,
    this.titulo = 'Saldo disponible',
  });

  final double saldo;
  final String titulo;

  @override
  Widget build(BuildContext context) {
    final colores = ColoresFinza.de(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                formatearDinero(saldo),
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: saldo < 0 ? colores.gasto : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
