import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/factura.dart';
import '../models/movimiento.dart';
import '../providers/finanzas_provider.dart';
import '../screens/factura_form_screen.dart';
import '../screens/movimiento_form_screen.dart';
import '../utils/formato.dart';

/// Acciones sobre movimientos y facturas que se usan desde varias pantallas.

void mostrarMensaje(
  BuildContext context,
  String texto, {
  SnackBarAction? accion,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(texto), action: accion));
}

Future<void> abrirFormularioMovimiento(
  BuildContext context, {
  Movimiento? movimiento,
}) async {
  final guardado = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => MovimientoFormScreen(movimiento: movimiento),
    ),
  );

  if (guardado == true && context.mounted) {
    mostrarMensaje(
      context,
      movimiento == null ? 'Movimiento guardado.' : 'Movimiento actualizado.',
    );
  }
}

Future<void> abrirFormularioFactura(
  BuildContext context, {
  Factura? factura,
}) async {
  final guardada = await Navigator.of(context).push<bool>(
    MaterialPageRoute(builder: (_) => FacturaFormScreen(factura: factura)),
  );

  if (guardada == true && context.mounted) {
    mostrarMensaje(
      context,
      factura == null ? 'Factura guardada.' : 'Factura actualizada.',
    );
  }
}

Future<void> eliminarMovimientoConDeshacer(
  BuildContext context,
  Movimiento movimiento,
) async {
  final finanzas = context.read<FinanzasProvider>();
  await finanzas.eliminarMovimiento(movimiento);

  if (!context.mounted) return;
  mostrarMensaje(
    context,
    'Movimiento enviado a la papelera.',
    accion: SnackBarAction(
      label: 'Deshacer',
      onPressed: () => finanzas.restaurarMovimiento(movimiento),
    ),
  );
}

Future<void> eliminarFacturaConDeshacer(
  BuildContext context,
  Factura factura,
) async {
  final finanzas = context.read<FinanzasProvider>();
  await finanzas.eliminarFactura(factura);

  if (!context.mounted) return;
  mostrarMensaje(
    context,
    'Factura enviada a la papelera.',
    accion: SnackBarAction(
      label: 'Deshacer',
      onPressed: () => finanzas.restaurarFactura(factura),
    ),
  );
}

Future<void> cambiarEstadoFactura(
  BuildContext context,
  Factura factura, {
  required bool pagada,
}) async {
  final siguiente = await context.read<FinanzasProvider>().cambiarEstadoFactura(
    factura,
    pagada: pagada,
  );

  if (!context.mounted) return;

  if (!pagada) {
    mostrarMensaje(context, 'Factura marcada como pendiente.');
  } else if (siguiente != null) {
    mostrarMensaje(
      context,
      'Factura pagada. La próxima vence el '
      '${formatearFecha(siguiente.fechaVencimiento)}.',
    );
  } else {
    mostrarMensaje(context, 'Factura marcada como pagada.');
  }
}

Future<void> mostrarOpcionesMovimiento(
  BuildContext context,
  Movimiento movimiento,
) async {
  final opcion = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Editar movimiento'),
            onTap: () => Navigator.pop(context, 'editar'),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Eliminar movimiento'),
            subtitle: const Text('Se puede recuperar desde la papelera'),
            onTap: () => Navigator.pop(context, 'eliminar'),
          ),
        ],
      ),
    ),
  );

  if (!context.mounted) return;

  if (opcion == 'editar') {
    await abrirFormularioMovimiento(context, movimiento: movimiento);
  } else if (opcion == 'eliminar') {
    await eliminarMovimientoConDeshacer(context, movimiento);
  }
}

Future<void> mostrarOpcionesFactura(
  BuildContext context,
  Factura factura,
) async {
  final opcion = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Editar factura'),
            onTap: () => Navigator.pop(context, 'editar'),
          ),
          ListTile(
            leading: Icon(
              factura.pagada
                  ? Icons.pending_outlined
                  : Icons.check_circle_outline,
            ),
            title: Text(factura.pagada ? 'Marcar pendiente' : 'Marcar pagada'),
            onTap: () => Navigator.pop(context, 'estado'),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Eliminar factura'),
            subtitle: const Text('Se puede recuperar desde la papelera'),
            onTap: () => Navigator.pop(context, 'eliminar'),
          ),
        ],
      ),
    ),
  );

  if (!context.mounted) return;

  switch (opcion) {
    case 'editar':
      await abrirFormularioFactura(context, factura: factura);
    case 'estado':
      await cambiarEstadoFactura(context, factura, pagada: !factura.pagada);
    case 'eliminar':
      await eliminarFacturaConDeshacer(context, factura);
  }
}
