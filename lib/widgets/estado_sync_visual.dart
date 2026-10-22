import 'package:flutter/material.dart';

import '../services/sync_service.dart';
import '../theme/app_theme.dart';

/// Ícono, color y texto corto del estado de la sincronización. Lo usan la
/// barra superior y Ajustes para mostrar lo mismo.
({IconData icono, Color? color, String texto}) estadoSyncVisual(
  BuildContext context,
  SyncService sync,
) {
  final colores = ColoresFinza.de(context);

  switch (sync.estado) {
    case EstadoSync.noConfigurado:
    case EstadoSync.desconectado:
      return (icono: Icons.cloud_outlined, color: null, texto: 'Sin conectar');
    case EstadoSync.sincronizando:
      return (
        icono: Icons.cloud_sync_outlined,
        color: null,
        texto: 'Sincronizando…',
      );
    case EstadoSync.sinConexion:
      return (
        icono: Icons.cloud_upload_outlined,
        color: colores.alerta,
        texto: 'Sin conexión: se sincroniza al volver',
      );
    case EstadoSync.sinPermiso:
    case EstadoSync.error:
      return (
        icono: Icons.cloud_off_outlined,
        color: colores.gasto,
        texto: 'Error al sincronizar',
      );
    case EstadoSync.listo:
      return sync.hayCambiosPendientes
          ? (
              icono: Icons.cloud_upload_outlined,
              color: null,
              texto: 'Cambios por subir',
            )
          : (
              icono: Icons.cloud_done_outlined,
              color: null,
              texto: 'Sincronizado con Drive',
            );
  }
}
