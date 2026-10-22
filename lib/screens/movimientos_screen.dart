import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/categorias.dart';
import '../models/filtro_movimientos.dart';
import '../providers/finanzas_provider.dart';
import '../providers/preferencias_provider.dart';
import '../services/sync_service.dart';
import '../theme/app_theme.dart';
import '../utils/formato.dart';
import '../widgets/acciones.dart';
import '../widgets/estado_vacio.dart';
import '../widgets/filtros_movimientos_sheet.dart';
import '../widgets/tarjeta_movimiento.dart';

class MovimientosScreen extends StatefulWidget {
  const MovimientosScreen({super.key});

  @override
  State<MovimientosScreen> createState() => _MovimientosScreenState();
}

class _MovimientosScreenState extends State<MovimientosScreen> {
  final _busquedaController = TextEditingController();
  String _busqueda = '';

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  void _cambiarTipo(PreferenciasProvider preferencias, String tipo) {
    final filtro = preferencias.filtroMovimientos;

    // Las categorías que no son del tipo elegido dejarían la lista vacía.
    final categorias = tipo == 'Todos'
        ? filtro.categorias
        : filtro.categorias
              .where(Categorias.deMovimiento(tipo).contains)
              .toSet();

    preferencias.filtroMovimientos = filtro.copyWith(
      tipo: tipo,
      categorias: categorias,
    );
  }

  Future<void> _abrirFiltros(PreferenciasProvider preferencias) async {
    final filtro = await mostrarFiltrosMovimientos(
      context,
      preferencias.filtroMovimientos,
    );
    if (filtro != null) preferencias.filtroMovimientos = filtro;
  }

  @override
  Widget build(BuildContext context) {
    final finanzas = context.watch<FinanzasProvider>();
    final preferencias = context.watch<PreferenciasProvider>();
    final filtro = preferencias.filtroMovimientos;

    if (finanzas.cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    final filtrados = filtro.aplicar(finanzas.movimientos, busqueda: _busqueda);
    final balance = filtrados.fold<double>(
      0,
      (total, m) => total + (m.esIngreso ? m.monto : -m.monto),
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            children: [
              TextField(
                controller: _busquedaController,
                decoration: InputDecoration(
                  hintText: 'Buscar movimiento...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _busqueda.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _busquedaController.clear();
                            setState(() => _busqueda = '');
                          },
                        )
                      : null,
                ),
                onChanged: (valor) => setState(() => _busqueda = valor),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final tipo in ['Todos', 'Ingreso', 'Gasto']) ...[
                            FilterChip(
                              label: Text(
                                tipo == 'Todos'
                                    ? 'Todos'
                                    : tipo == 'Ingreso'
                                    ? 'Ingresos'
                                    : 'Gastos',
                              ),
                              selected: filtro.tipo == tipo,
                              onSelected: (_) =>
                                  _cambiarTipo(preferencias, tipo),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Badge(
                    isLabelVisible: filtro.activos > 0,
                    label: Text('${filtro.activos}'),
                    child: IconButton.filledTonal(
                      tooltip: 'Filtros',
                      icon: const Icon(Icons.tune),
                      onPressed: () => _abrirFiltros(preferencias),
                    ),
                  ),
                ],
              ),
              if (filtro.activos > 0 ||
                  _busqueda.isNotEmpty ||
                  filtro.tipo != 'Todos')
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${filtrados.length} movimiento${filtrados.length == 1 ? '' : 's'}'
                          '${filtro.periodo != PeriodoFiltro.todo ? ' · ${filtro.periodo.etiqueta.toLowerCase()}' : ''}',
                        ),
                      ),
                      Text(
                        formatearDinero(balance),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: balance < 0
                              ? ColoresFinza.de(context).gasto
                              : ColoresFinza.de(context).ingreso,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => context.read<SyncService>().sincronizar(),
            child: filtrados.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      finanzas.movimientos.isEmpty
                          ? const EstadoVacio(
                              icono: Icons.account_balance_wallet_outlined,
                              titulo: 'Todavía no tienes movimientos.',
                              mensaje: 'Agrega tu primer ingreso o gasto con el botón +.',
                            )
                          : EstadoVacio(
                              icono: Icons.search_off,
                              titulo: 'No se encontraron movimientos.',
                              mensaje: 'Prueba con otro término o filtro.',
                              accion: TextButton(
                                onPressed: () {
                                  _busquedaController.clear();
                                  setState(() => _busqueda = '');
                                  preferencias.filtroMovimientos =
                                      const FiltroMovimientos();
                                },
                                child: const Text('Quitar filtros'),
                              ),
                            ),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: filtrados.length,
                    itemBuilder: (context, index) {
                      final movimiento = filtrados[index];
                      return TarjetaMovimiento(
                        movimiento: movimiento,
                        onTap: () =>
                            mostrarOpcionesMovimiento(context, movimiento),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}
