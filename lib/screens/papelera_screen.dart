import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/factura.dart';
import '../models/movimiento.dart';
import '../providers/finanzas_provider.dart';
import '../utils/formato.dart';
import '../widgets/acciones.dart';
import '../widgets/estado_vacio.dart';
import '../widgets/tarjeta_movimiento.dart';

/// Movimientos y facturas eliminados en los últimos 30 días. Se pueden
/// restaurar o eliminar definitivamente. Inspirada en la papelera de top-list.
class PapeleraScreen extends StatelessWidget {
  const PapeleraScreen({super.key});

  Future<bool> _confirmar(BuildContext context, String mensaje) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar definitivamente?'),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    return confirmado == true;
  }

  String _diasRestantes(DateTime eliminadoEn) {
    final purga = eliminadoEn.add(
      const Duration(days: FinanzasProvider.diasEnPapelera),
    );
    final dias = purga.difference(DateTime.now()).inDays;
    if (dias <= 0) return 'Se elimina en menos de un día';
    return 'Se elimina en $dias día${dias == 1 ? '' : 's'}';
  }

  @override
  Widget build(BuildContext context) {
    final finanzas = context.watch<FinanzasProvider>();
    final movimientos = finanzas.movimientosEnPapelera;
    final facturas = finanzas.facturasEnPapelera;
    final vacia = movimientos.isEmpty && facturas.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Papelera'),
        actions: [
          if (!vacia)
            TextButton(
              onPressed: () async {
                if (await _confirmar(
                      context,
                      'Se eliminarán ${movimientos.length + facturas.length} '
                      'elementos y no se podrán recuperar.',
                    ) &&
                    context.mounted) {
                  await finanzas.vaciarPapelera();
                }
              },
              child: const Text('Vaciar'),
            ),
        ],
      ),
      body: vacia
          ? const Center(
              child: EstadoVacio(
                icono: Icons.delete_outline,
                titulo: 'La papelera está vacía',
                mensaje:
                    'Lo que elimines queda acá ${FinanzasProvider.diasEnPapelera} '
                    'días por si lo necesitas recuperar.',
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (movimientos.isNotEmpty) ...[
                  const _Seccion('Movimientos'),
                  for (final movimiento in movimientos)
                    _ElementoPapelera(
                      subtitulo: _diasRestantes(movimiento.eliminadoEn!),
                      onRestaurar: () async {
                        await finanzas.restaurarMovimiento(movimiento);
                        if (context.mounted) {
                          mostrarMensaje(context, 'Movimiento restaurado.');
                        }
                      },
                      onEliminar: () async {
                        if (await _confirmar(
                              context,
                              '"${movimiento.descripcion}" no se podrá recuperar.',
                            ) &&
                            context.mounted) {
                          await finanzas.eliminarDefinitivamenteMovimiento(
                            movimiento,
                          );
                        }
                      },
                      child: _movimiento(movimiento),
                    ),
                ],
                if (facturas.isNotEmpty) ...[
                  const _Seccion('Facturas'),
                  for (final factura in facturas)
                    _ElementoPapelera(
                      subtitulo: _diasRestantes(factura.eliminadoEn!),
                      onRestaurar: () async {
                        await finanzas.restaurarFactura(factura);
                        if (context.mounted) {
                          mostrarMensaje(context, 'Factura restaurada.');
                        }
                      },
                      onEliminar: () async {
                        if (await _confirmar(
                              context,
                              '"${factura.nombre}" no se podrá recuperar.',
                            ) &&
                            context.mounted) {
                          await finanzas.eliminarDefinitivamenteFactura(
                            factura,
                          );
                        }
                      },
                      child: _factura(factura),
                    ),
                ],
              ],
            ),
    );
  }

  Widget _movimiento(Movimiento movimiento) {
    return TarjetaMovimiento(movimiento: movimiento);
  }

  Widget _factura(Factura factura) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.receipt_long)),
        title: Text(
          factura.nombre,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${factura.categoria} • Vence ${formatearFecha(factura.fechaVencimiento)}',
        ),
        trailing: Text(
          formatearDinero(factura.monto),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _Seccion extends StatelessWidget {
  const _Seccion(this.titulo);

  final String titulo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Text(
        titulo,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _ElementoPapelera extends StatelessWidget {
  const _ElementoPapelera({
    required this.child,
    required this.subtitulo,
    required this.onRestaurar,
    required this.onEliminar,
  });

  final Widget child;
  final String subtitulo;
  final VoidCallback onRestaurar;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          child,
          Row(
            children: [
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  subtitulo,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onEliminar,
                icon: const Icon(Icons.delete_forever_outlined, size: 18),
                label: const Text('Eliminar'),
              ),
              FilledButton.tonalIcon(
                onPressed: onRestaurar,
                icon: const Icon(Icons.restore, size: 18),
                label: const Text('Restaurar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
