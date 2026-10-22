import 'dart:async';

import 'package:flutter/material.dart';

OverlayEntry? _bannerActual;

/// Muestra un banner flotante arriba de la pantalla. Se cierra solo a los
/// [duracion] segundos, al tocarlo o con la X. Adaptado de top-list.
void mostrarBannerSuperior(
  BuildContext context, {
  required String titulo,
  required String mensaje,
  IconData icono = Icons.notifications_rounded,
  Color? color,
  Duration duracion = const Duration(seconds: 6),
  VoidCallback? onTap,
}) {
  _bannerActual?.remove();
  final overlay = Overlay.of(context, rootOverlay: true);
  late OverlayEntry entrada;
  Timer? temporizador;

  void cerrar() {
    temporizador?.cancel();
    if (entrada.mounted) entrada.remove();
    if (identical(_bannerActual, entrada)) _bannerActual = null;
  }

  entrada = OverlayEntry(
    builder: (_) => _BannerSuperior(
      titulo: titulo,
      mensaje: mensaje,
      icono: icono,
      color: color,
      onTap: () {
        cerrar();
        onTap?.call();
      },
      onCerrar: cerrar,
    ),
  );
  _bannerActual = entrada;
  overlay.insert(entrada);
  temporizador = Timer(duracion, cerrar);
}

class _BannerSuperior extends StatefulWidget {
  const _BannerSuperior({
    required this.titulo,
    required this.mensaje,
    required this.icono,
    required this.color,
    required this.onTap,
    required this.onCerrar,
  });

  final String titulo;
  final String mensaje;
  final IconData icono;
  final Color? color;
  final VoidCallback onTap;
  final VoidCallback onCerrar;

  @override
  State<_BannerSuperior> createState() => _BannerSuperiorState();
}

class _BannerSuperiorState extends State<_BannerSuperior>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _desplazamiento;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _desplazamiento = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final colorIcono = widget.color ?? colorScheme.primary;

    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 12,
      right: 12,
      child: SlideTransition(
        position: _desplazamiento,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: widget.onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colorScheme.outlineVariant),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      color: colorIcono.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(widget.icono, color: colorIcono, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.titulo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.mensaje,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      Icons.close,
                      color: colorScheme.outline,
                      size: 16,
                    ),
                    onPressed: widget.onCerrar,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
