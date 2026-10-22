import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_info.dart';
import '../models/actualizacion.dart';
import '../services/actualizacion_service.dart';
import 'acciones.dart';

/// Busca una versión nueva y, si hay, ofrece descargarla e instalarla.
///
/// Con [manual] en true (botón de Ajustes) avisa también cuando ya está al
/// día o cuando falla la consulta; al abrir la app no molesta.
Future<void> verificarActualizacion(
  BuildContext context, {
  bool manual = false,
}) async {
  final servicio = context.read<ActualizacionService>();
  Actualizacion? actualizacion;

  try {
    actualizacion = await servicio.buscar(manual: manual);
  } catch (e) {
    if (manual && context.mounted) {
      mostrarMensaje(context, 'No se pudo buscar actualizaciones. $e');
    }
    return;
  }

  if (!context.mounted) return;

  if (actualizacion == null) {
    if (manual) {
      mostrarMensaje(
        context,
        'Ya tienes la última versión (${AppInfo.versionLabel}).',
      );
    }
    return;
  }

  final instalar = await showDialog<bool>(
    context: context,
    builder: (context) => _DialogoDisponible(actualizacion: actualizacion!),
  );

  if (!context.mounted) return;

  if (instalar != true) {
    servicio.posponer(actualizacion);
    return;
  }

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        _DialogoDescarga(actualizacion: actualizacion!, servicio: servicio),
  );
}

class _DialogoDisponible extends StatelessWidget {
  const _DialogoDisponible({required this.actualizacion});

  final Actualizacion actualizacion;

  @override
  Widget build(BuildContext context) {
    final cambios = actualizacion.cambios;
    final tamano = actualizacion.tamano;

    return AlertDialog(
      icon: const Icon(Icons.system_update),
      title: const Text('Actualización disponible'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Finza ${actualizacion.etiqueta}'
            '${tamano != null ? ' · ${_mb(tamano)}' : ''}\n'
            'Tienes la ${AppInfo.versionLabel}.',
          ),
          if (cambios != null && cambios.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Novedades',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(cambios),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Más tarde'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Actualizar'),
        ),
      ],
    );
  }
}

class _DialogoDescarga extends StatefulWidget {
  const _DialogoDescarga({required this.actualizacion, required this.servicio});

  final Actualizacion actualizacion;
  final ActualizacionService servicio;

  @override
  State<_DialogoDescarga> createState() => _DialogoDescargaState();
}

class _DialogoDescargaState extends State<_DialogoDescarga> {
  double? _progreso;
  int _bytes = 0;
  String? _error;
  String? _rutaApk;
  bool _cancelada = false;

  @override
  void initState() {
    super.initState();
    _descargar();
  }

  Future<void> _descargar() async {
    setState(() {
      _error = null;
      _progreso = null;
      _bytes = 0;
    });

    try {
      final ruta = await widget.servicio.descargar(
        widget.actualizacion,
        cancelada: () => _cancelada,
        progreso: (progreso, bytes) {
          if (mounted) {
            setState(() {
              _progreso = progreso;
              _bytes = bytes;
            });
          }
        },
      );
      if (!mounted) return;
      setState(() => _rutaApk = ruta);
      await _instalar();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _instalar() async {
    try {
      await widget.servicio.instalar(_rutaApk!);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final descargando = _rutaApk == null && _error == null;

    return AlertDialog(
      title: Text(descargando ? 'Descargando…' : 'Actualización'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null)
            Text(_error!)
          else if (descargando) ...[
            LinearProgressIndicator(value: _progreso),
            const SizedBox(height: 12),
            Text(
              _progreso == null
                  ? _mb(_bytes)
                  : '${(_progreso! * 100).round()}% · ${_mb(_bytes)}',
            ),
          ] else
            const Text(
              'Descarga lista. Si el instalador no se abrió, tócalo de nuevo. '
              'Android puede pedirte permitir instalar apps de Finza.',
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            _cancelada = true;
            Navigator.pop(context);
          },
          child: Text(descargando ? 'Cancelar' : 'Cerrar'),
        ),
        if (_error != null && _rutaApk == null)
          FilledButton(onPressed: _descargar, child: const Text('Reintentar')),
        if (_rutaApk != null)
          FilledButton(onPressed: _instalar, child: const Text('Instalar')),
      ],
    );
  }
}

String _mb(int bytes) => '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
