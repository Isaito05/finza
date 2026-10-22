import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_info.dart';
import '../providers/finanzas_provider.dart';
import '../providers/preferencias_provider.dart';
import '../services/recordatorios_service.dart';
import '../services/sync_service.dart';
import '../utils/formato.dart';
import '../widgets/dialogo_actualizacion.dart';
import '../widgets/estado_sync_visual.dart';
import 'papelera_screen.dart';

class AjustesScreen extends StatelessWidget {
  const AjustesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final preferencias = context.watch<PreferenciasProvider>();
    final enPapelera =
        context.watch<FinanzasProvider>().movimientosEnPapelera.length +
        context.watch<FinanzasProvider>().facturasEnPapelera.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const _Seccion('Sincronización'),
          const _TarjetaSincronizacion(),
          const _Seccion('Apariencia'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text('Sistema'),
                  icon: Icon(Icons.brightness_auto_outlined),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text('Claro'),
                  icon: Icon(Icons.light_mode_outlined),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text('Oscuro'),
                  icon: Icon(Icons.dark_mode_outlined),
                ),
              ],
              selected: {preferencias.modoTema},
              onSelectionChanged: (modo) => preferencias.modoTema = modo.first,
            ),
          ),
          const _Seccion('Recordatorios'),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_outlined),
            title: const Text('Avisos de facturas'),
            subtitle: const Text(
              'El día antes y el día del vencimiento, a las 9:00',
            ),
            value: preferencias.recordatoriosActivos,
            onChanged: (activos) async {
              preferencias.recordatoriosActivos = activos;
              if (activos) {
                await context.read<RecordatoriosService>().pedirPermiso();
              }
            },
          ),
          const _Seccion('Datos'),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Papelera'),
            subtitle: Text(
              enPapelera == 0
                  ? 'Vacía'
                  : '$enPapelera elemento${enPapelera == 1 ? '' : 's'}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const PapeleraScreen())),
          ),
          const _Seccion('Acerca de'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Versión'),
            subtitle: Text(AppInfo.versionLabel),
          ),
          ListTile(
            leading: const Icon(Icons.system_update_outlined),
            title: const Text('Buscar actualizaciones'),
            onTap: () => verificarActualizacion(context, manual: true),
          ),
        ],
      ),
    );
  }
}

class _TarjetaSincronizacion extends StatelessWidget {
  const _TarjetaSincronizacion();

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncService>();
    final visual = estadoSyncVisual(context, sync);
    final ultima = sync.ultimaSincronizacion;
    final cuenta = sync.email ?? 'Cuenta de Google';

    final String titulo;
    final List<String> lineas;
    final List<Widget> acciones;

    final botonSincronizar = FilledButton.tonalIcon(
      onPressed: sync.estado == EstadoSync.sincronizando
          ? null
          : sync.sincronizar,
      icon: const Icon(Icons.sync),
      label: Text(
        sync.estado == EstadoSync.sinConexion
            ? 'Reintentar ahora'
            : 'Sincronizar ahora',
      ),
    );
    final botonDesconectar = TextButton(
      onPressed: () => _confirmarDesconexion(context, sync),
      child: const Text('Desconectar'),
    );

    switch (sync.estado) {
      case EstadoSync.noConfigurado:
        titulo = 'No disponible en esta versión';
        lineas = [
          'La app se compiló sin el Client ID de Google '
              '(FINZA_GOOGLE_CLIENT_ID en finza_config.json).',
        ];
        acciones = [];
      case EstadoSync.desconectado:
        titulo = 'Guarda tus datos en Google Drive';
        lineas = [
          'Respaldo automático y los mismos datos en todos tus celulares. '
              'Finza solo puede ver el archivo que ella misma crea en tu Drive.',
          if (sync.error != null) sync.error!,
        ];
        acciones = [
          FilledButton.icon(
            onPressed: sync.conectar,
            icon: const Icon(Icons.login),
            label: const Text('Conectar con Google'),
          ),
        ];
      case EstadoSync.sinPermiso:
        titulo = cuenta;
        lineas = [
          'Falta el permiso para guardar en tu Drive, o hay que volver a '
              'elegir la cuenta. Tus datos siguen guardados en este celular.',
          if (sync.error != null) 'Detalle: ${sync.error}',
        ];
        acciones = [
          FilledButton(
            onPressed: sync.conectar,
            child: const Text('Dar permiso'),
          ),
          botonDesconectar,
        ];
      case EstadoSync.sinConexion:
        final reintento = sync.proximoReintento;
        titulo = cuenta;
        lineas = [
          'Sin conexión con Google Drive. Tus datos están guardados en este '
              'celular y se sincronizan solos cuando vuelva el servicio.',
          if (reintento != null)
            'Próximo intento: ${formatearHora(reintento)}.',
        ];
        acciones = [botonSincronizar, botonDesconectar];
      case EstadoSync.listo:
      case EstadoSync.sincronizando:
      case EstadoSync.error:
        titulo = cuenta;
        lineas = [
          if (sync.estado == EstadoSync.sincronizando)
            'Sincronizando…'
          else if (sync.estado == EstadoSync.error)
            'Error: ${sync.error}'
          else if (ultima == null)
            'Conectado'
          else
            'Última sincronización: ${formatearFecha(ultima)} '
                '${formatearHora(ultima)}',
        ];
        acciones = [botonSincronizar, botonDesconectar];
    }

    if (sync.vinculado &&
        sync.hayCambiosPendientes &&
        sync.estado != EstadoSync.sincronizando) {
      lineas.add('Hay cambios de este celular pendientes de subir.');
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(visual.icono, color: visual.color),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    titulo,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final linea in lineas)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(linea),
              ),
            if (acciones.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: acciones),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmarDesconexion(
    BuildContext context,
    SyncService sync,
  ) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Desconectar Google Drive?'),
        content: const Text(
          'Tus datos se quedan en este celular y en tu Drive, pero dejarán '
          'de sincronizarse.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Desconectar'),
          ),
        ],
      ),
    );
    if (confirmado == true) await sync.desconectar();
  }
}

class _Seccion extends StatelessWidget {
  const _Seccion(this.titulo);

  final String titulo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        titulo,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
