import 'package:flutter/material.dart';

/// Mensaje centrado para listas vacías, con una acción opcional.
class EstadoVacio extends StatelessWidget {
  const EstadoVacio({
    super.key,
    required this.icono,
    required this.titulo,
    this.mensaje,
    this.accion,
  });

  final IconData icono;
  final String titulo;
  final String? mensaje;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 64, color: colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          if (mensaje != null) ...[
            const SizedBox(height: 8),
            Text(mensaje!, textAlign: TextAlign.center),
          ],
          if (accion != null) ...[const SizedBox(height: 20), accion!],
        ],
      ),
    );
  }
}
