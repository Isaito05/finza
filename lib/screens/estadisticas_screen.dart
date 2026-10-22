import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/finanzas_provider.dart';
import '../services/sync_service.dart';
import '../theme/app_theme.dart';
import '../utils/formato.dart';
import '../widgets/tarjeta_resumen.dart';

class EstadisticasScreen extends StatelessWidget {
  const EstadisticasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final finanzas = context.watch<FinanzasProvider>();
    final colores = ColoresFinza.de(context);

    if (finanzas.cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    final totalIngresos = finanzas.totalIngresos;
    final totalGastos = finanzas.totalGastos;
    final totalGeneral = totalIngresos + totalGastos;

    final porcentajeIngresos = totalGeneral == 0
        ? 0.0
        : totalIngresos / totalGeneral;
    final porcentajeGastos = totalGeneral == 0
        ? 0.0
        : totalGastos / totalGeneral;

    final gastosPorCategoria = <String, double>{};
    for (final movimiento in finanzas.movimientos.where((m) => !m.esIngreso)) {
      gastosPorCategoria[movimiento.categoria] =
          (gastosPorCategoria[movimiento.categoria] ?? 0) + movimiento.monto;
    }

    final categoriasOrdenadas = gastosPorCategoria.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return RefreshIndicator(
      onRefresh: () => context.read<SyncService>().sincronizar(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          Row(
            children: [
              Expanded(
                child: TarjetaResumen(esIngreso: true, valor: totalIngresos),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TarjetaResumen(esIngreso: false, valor: totalGastos),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TarjetaSaldo(saldo: finanzas.saldo, titulo: 'Saldo actual'),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ingresos vs. gastos',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  Text('Ingresos · ${(porcentajeIngresos * 100).round()}%'),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: porcentajeIngresos,
                    minHeight: 10,
                    color: colores.ingreso,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  const SizedBox(height: 16),
                  Text('Gastos · ${(porcentajeGastos * 100).round()}%'),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: porcentajeGastos,
                    minHeight: 10,
                    color: colores.gasto,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Total de movimientos: ${finanzas.movimientos.length}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Gastos por categoría',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  if (categoriasOrdenadas.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Text('Todavía no tienes gastos registrados.'),
                      ),
                    )
                  else
                    for (final entrada in categoriasOrdenadas)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    entrada.key,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Text(
                                  formatearDinero(entrada.value),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 7),
                            LinearProgressIndicator(
                              value: totalGastos == 0
                                  ? 0
                                  : entrada.value / totalGastos,
                              minHeight: 8,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                        ),
                      ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
