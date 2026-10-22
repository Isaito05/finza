import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/finanzas_provider.dart';
import '../services/sync_service.dart';
import '../utils/estado_factura.dart';
import '../theme/app_theme.dart';
import '../widgets/acciones.dart';
import '../widgets/animaciones.dart';
import '../widgets/estado_vacio.dart';
import '../widgets/tarjeta_movimiento.dart';
import '../widgets/tarjeta_resumen.dart';
import 'home_shell.dart';

class InicioScreen extends StatelessWidget {
  const InicioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final finanzas = context.watch<FinanzasProvider>();

    if (finanzas.cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    final recientes = finanzas.movimientos.take(5).toList();
    final porVencer = finanzas.facturas.where((f) {
      final estado = estadoDeFactura(f);
      return estado == EstadoFactura.vencida ||
          estado == EstadoFactura.venceHoy ||
          estado == EstadoFactura.proxima;
    }).length;

    return RefreshIndicator(
      onRefresh: () => context.read<SyncService>().sincronizar(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          Aparecer(child: TarjetaSaldo(saldo: finanzas.saldo)),
          const SizedBox(height: 14),
          Aparecer(
            orden: 1,
            child: Row(
            children: [
              Expanded(
                child: TarjetaResumen(
                  esIngreso: true,
                  valor: finanzas.totalIngresos,
                  centrada: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TarjetaResumen(
                  esIngreso: false,
                  valor: finanzas.totalGastos,
                  centrada: true,
                ),
              ),
            ],
            ),
          ),
          if (porVencer > 0) ...[
            const SizedBox(height: 14),
            Aparecer(orden: 2, child: _AvisoFacturas(cantidad: porVencer)),
          ],
          const SizedBox(height: 26),
          Aparecer(
            orden: 3,
            child: Text(
              'Movimientos recientes',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 12),
          if (recientes.isEmpty)
            const Aparecer(
              orden: 4,
              child: Card(
                child: EstadoVacio(
                  icono: Icons.account_balance_wallet_outlined,
                  titulo: 'Todavía no tienes movimientos.',
                  mensaje: 'Toca "Agregar" para registrar tu primer ingreso o gasto.',
                ),
              ),
            )
          else
            for (var i = 0; i < recientes.length; i++)
              Aparecer(
                key: ValueKey(recientes[i].id),
                orden: 4 + i,
                child: TarjetaMovimiento(
                  movimiento: recientes[i],
                  onTap: () => mostrarOpcionesMovimiento(context, recientes[i]),
                ),
              ),
        ],
      ),
    );
  }
}

/// Aviso de facturas vencidas o por vencer, con el color de alerta.
class _AvisoFacturas extends StatelessWidget {
  const _AvisoFacturas({required this.cantidad});

  final int cantidad;

  @override
  Widget build(BuildContext context) {
    final alerta = ColoresFinza.de(context).alerta;
    final esOscuro = Theme.of(context).brightness == Brightness.dark;

    return Presionable(
      onTap: () => HomeShell.tabIndex.value = HomeShell.tabFacturas,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: alerta.withValues(alpha: esOscuro ? 0.16 : 0.10),
          borderRadius: BorderRadius.circular(AppTheme.radio),
          border: Border.all(color: alerta.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: alerta,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                cantidad == 1
                    ? '1 factura vencida o por vencer'
                    : '$cantidad facturas vencidas o por vencer',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: alerta),
          ],
        ),
      ),
    );
  }
}
