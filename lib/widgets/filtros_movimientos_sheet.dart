import 'package:flutter/material.dart';

import '../models/categorias.dart';
import '../models/filtro_movimientos.dart';
import '../utils/formato.dart';

/// Abre el panel de filtros de Movimientos. Devuelve el filtro elegido o
/// null si se cerró sin aplicar.
Future<FiltroMovimientos?> mostrarFiltrosMovimientos(
  BuildContext context,
  FiltroMovimientos actual,
) {
  return showModalBottomSheet<FiltroMovimientos>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _FiltrosMovimientosSheet(inicial: actual),
  );
}

class _FiltrosMovimientosSheet extends StatefulWidget {
  const _FiltrosMovimientosSheet({required this.inicial});

  final FiltroMovimientos inicial;

  @override
  State<_FiltrosMovimientosSheet> createState() =>
      _FiltrosMovimientosSheetState();
}

class _FiltrosMovimientosSheetState extends State<_FiltrosMovimientosSheet> {
  late FiltroMovimientos _filtro = widget.inicial;

  Future<void> _elegirRango() async {
    final ahora = DateTime.now();
    final rango = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(ahora.year + 1, 12, 31),
      initialDateRange: _filtro.desde != null && _filtro.hasta != null
          ? DateTimeRange(start: _filtro.desde!, end: _filtro.hasta!)
          : null,
    );

    if (rango != null && mounted) {
      setState(() {
        _filtro = _filtro.copyWith(
          periodo: PeriodoFiltro.personalizado,
          desde: rango.start,
          hasta: rango.end,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final categorias = _filtro.tipo == 'Todos'
        ? Categorias.todasDeMovimientos
        : Categorias.deMovimiento(_filtro.tipo);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Filtrar movimientos',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            const _Titulo('Periodo'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final periodo in PeriodoFiltro.values)
                  ChoiceChip(
                    label: Text(
                      periodo == PeriodoFiltro.personalizado &&
                              _filtro.periodo == periodo &&
                              _filtro.desde != null &&
                              _filtro.hasta != null
                          ? '${formatearFecha(_filtro.desde!)} - ${formatearFecha(_filtro.hasta!)}'
                          : periodo.etiqueta,
                    ),
                    selected: _filtro.periodo == periodo,
                    onSelected: (_) {
                      if (periodo == PeriodoFiltro.personalizado) {
                        _elegirRango();
                      } else {
                        setState(
                          () => _filtro = _filtro.copyWith(periodo: periodo),
                        );
                      }
                    },
                  ),
              ],
            ),
            const SizedBox(height: 20),
            const _Titulo('Categorías'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final categoria in categorias)
                  FilterChip(
                    label: Text(categoria),
                    selected: _filtro.categorias.contains(categoria),
                    onSelected: (seleccionada) {
                      final nuevas = {..._filtro.categorias};
                      seleccionada
                          ? nuevas.add(categoria)
                          : nuevas.remove(categoria);
                      setState(() {
                        _filtro = _filtro.copyWith(categorias: nuevas);
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 20),
            const _Titulo('Ordenar por'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final orden in OrdenMovimientos.values)
                  ChoiceChip(
                    label: Text(orden.etiqueta),
                    selected: _filtro.orden == orden,
                    onSelected: (_) {
                      setState(() => _filtro = _filtro.copyWith(orden: orden));
                    },
                  ),
              ],
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(
                      context,
                      FiltroMovimientos(tipo: _filtro.tipo),
                    ),
                    child: const Text('Limpiar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, _filtro),
                    child: const Text('Aplicar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Titulo extends StatelessWidget {
  const _Titulo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        texto,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
      ),
    );
  }
}
