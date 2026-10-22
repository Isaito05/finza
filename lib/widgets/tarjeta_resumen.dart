import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'animaciones.dart';

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
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    final color = esIngreso ? colores.ingreso : colores.gasto;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: esOscuro ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radio),
        border: Border.all(color: color.withValues(alpha: esOscuro ? 0.30 : 0.18)),
      ),
      child: Column(
        crossAxisAlignment:
            centrada ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              esIngreso ? Icons.south_west_rounded : Icons.north_east_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            esIngreso ? 'Ingresos' : 'Gastos',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: MontoAnimado(
              valor: valor,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta grande del saldo, con el degradado de la marca.
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
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: AppTheme.degradadoMarca,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.indigo.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Círculos decorativos, como en el logo.
          Positioned(
            right: -40,
            top: -50,
            child: _Circulo(tamano: 170, opacidad: 0.12),
          ),
          Positioned(
            right: 60,
            bottom: -70,
            child: _Circulo(tamano: 140, opacidad: 0.08),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: Colors.white70,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      titulo,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: MontoAnimado(
                    valor: saldo,
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -1,
                    ),
                  ),
                ),
                if (saldo < 0) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Gastas más de lo que ingresas',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Circulo extends StatelessWidget {
  const _Circulo({required this.tamano, required this.opacidad});

  final double tamano;
  final double opacidad;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tamano,
      height: tamano,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacidad),
      ),
    );
  }
}
