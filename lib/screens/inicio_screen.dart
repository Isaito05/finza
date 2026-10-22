import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/finanzas_provider.dart';
import '../services/sync_service.dart';
import '../utils/estado_factura.dart';
import '../widgets/acciones.dart';
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
          TarjetaSaldo(saldo: finanzas.saldo),
          const SizedBox(height: 16),
          Row(
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
          if (porVencer > 0) ...[
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.receipt_long),
                title: Text(
                  porVencer == 1
                      ? '1 factura vencida o por vencer'
                      : '$porVencer facturas vencidas o por vencer',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => HomeShell.tabIndex.value = HomeShell.tabFacturas,
              ),
            ),
          ],
          const SizedBox(height: 24),
          const Text(
            'Movimientos recientes',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          if (recientes.isEmpty)
            const Card(
              child: EstadoVacio(
                icono: Icons.account_balance_wallet_outlined,
                titulo: 'Todavía no tienes movimientos.',
                mensaje: 'Agrega tu primer ingreso o gasto.',
              ),
            )
          else
            for (final movimiento in recientes)
              TarjetaMovimiento(
                movimiento: movimiento,
                onTap: () => mostrarOpcionesMovimiento(context, movimiento),
              ),
        ],
      ),
    );
  }
}
