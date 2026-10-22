import 'package:flutter/material.dart';

import '../utils/formato.dart';

/// Monto que "cuenta" desde el valor anterior hasta el nuevo cuando cambia.
class MontoAnimado extends StatelessWidget {
  const MontoAnimado({
    super.key,
    required this.valor,
    this.style,
    this.prefijo = '',
  });

  final double valor;
  final TextStyle? style;
  final String prefijo;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: valor),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, actual, _) =>
          Text('$prefijo${formatearDinero(actual)}', style: style),
    );
  }
}

/// Aparece con un desvanecido y un leve desplazamiento hacia arriba.
/// `orden` escalona varios elementos de una misma pantalla.
class Aparecer extends StatefulWidget {
  const Aparecer({super.key, required this.child, this.orden = 0});

  final Widget child;
  final int orden;

  @override
  State<Aparecer> createState() => _AparecerState();
}

class _AparecerState extends State<Aparecer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controlador = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );
  late final Animation<double> _curva = CurvedAnimation(
    parent: _controlador,
    curve: Curves.easeOutCubic,
  );

  @override
  void initState() {
    super.initState();
    // Escalonado corto: con muchos elementos no debe sentirse lento.
    final retraso = Duration(milliseconds: 60 * widget.orden.clamp(0, 8));
    Future.delayed(retraso, () {
      if (mounted) _controlador.forward();
    });
  }

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curva,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(_curva),
        child: widget.child,
      ),
    );
  }
}

/// Se encoge un poco al presionar, como un botón físico.
class Presionable extends StatefulWidget {
  const Presionable({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<Presionable> createState() => _PresionableState();
}

class _PresionableState extends State<Presionable> {
  bool _presionado = false;

  void _cambiar(bool valor) {
    if (widget.onTap == null) return;
    setState(() => _presionado = valor);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _cambiar(true),
      onTapUp: (_) => _cambiar(false),
      onTapCancel: () => _cambiar(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _presionado ? 0.97 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
