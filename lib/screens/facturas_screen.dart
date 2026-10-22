import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/factura.dart';
import '../providers/finanzas_provider.dart';
import '../services/sync_service.dart';
import '../utils/formato.dart';
import '../widgets/acciones.dart';
import '../widgets/estado_vacio.dart';
import '../widgets/tarjeta_factura.dart';

class FacturasScreen extends StatelessWidget {
  const FacturasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final finanzas = context.watch<FinanzasProvider>();

    if (finanzas.cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    final facturas = finanzas.facturas;

    if (facturas.isEmpty) {
      return Center(
        child: EstadoVacio(
          icono: Icons.receipt_long,
          titulo: 'No tienes facturas',
          mensaje:
              'Agrega tu primera factura para comenzar a controlar tus pagos.',
          accion: FilledButton.icon(
            onPressed: () => abrirFormularioFactura(context),
            icon: const Icon(Icons.add),
            label: const Text('Agregar factura'),
          ),
        ),
      );
    }

    final pendientes = facturas.where((f) => !f.pagada).toList();
    // Las pagadas más recientes primero.
    final pagadas = facturas.where((f) => f.pagada).toList()
      ..sort((a, b) => b.fechaVencimiento.compareTo(a.fechaVencimiento));

    final totalPendiente = pendientes.fold<double>(
      0,
      (total, factura) => total + factura.monto,
    );

    Widget tarjeta(Factura factura) => TarjetaFactura(
      factura: factura,
      onTap: () => mostrarOpcionesFactura(context, factura),
      onCambiarEstado: (pagada) =>
          cambiarEstadoFactura(context, factura, pagada: pagada),
    );

    return RefreshIndicator(
      onRefresh: () => context.read<SyncService>().sincronizar(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const CircleAvatar(child: Icon(Icons.account_balance_wallet)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total pendiente',
                          style: TextStyle(fontSize: 15),
                        ),
                        const SizedBox(height: 5),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            formatearDinero(totalPendiente),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      Text(
                        '${pendientes.length}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text('pendientes'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (pendientes.isNotEmpty) ...[
            const Text(
              'Pendientes',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...pendientes.map(tarjeta),
          ],
          if (pagadas.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Pagadas',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...pagadas.map(tarjeta),
          ],
        ],
      ),
    );
  }
}
