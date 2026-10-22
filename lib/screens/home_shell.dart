import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/finanzas_provider.dart';
import '../services/sync_service.dart';
import '../theme/app_theme.dart';
import '../utils/estado_factura.dart';
import '../widgets/acciones.dart';
import '../widgets/dialogo_actualizacion.dart';
import '../widgets/estado_sync_visual.dart';
import '../widgets/top_notification_banner.dart';
import 'ajustes_screen.dart';
import 'estadisticas_screen.dart';
import 'facturas_screen.dart';
import 'inicio_screen.dart';
import 'movimientos_screen.dart';

/// Estructura principal: barra superior, pestañas y botón de agregar.
/// Mismo patrón que el `HomeShell` de top-list.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  static const tabInicio = 0;
  static const tabMovimientos = 1;
  static const tabEstadisticas = 2;
  static const tabFacturas = 3;

  /// Pestaña activa. Cualquier pantalla puede cambiarla (por ejemplo, el
  /// banner de facturas o una notificación abren Facturas).
  static final ValueNotifier<int> tabIndex = ValueNotifier(tabInicio);

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static const _titulos = ['Finza', 'Movimientos', 'Estadísticas', 'Facturas'];

  bool _bannerMostrado = false;

  // Se guarda la referencia: en dispose() ya no se puede usar context.read.
  late final FinanzasProvider _finanzas = context.read<FinanzasProvider>();

  @override
  void initState() {
    super.initState();
    HomeShell.tabIndex.addListener(_alCambiarTab);
    _finanzas.addListener(_mostrarBannerFacturas);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mostrarBannerFacturas();
      verificarActualizacion(context);
    });
  }

  @override
  void dispose() {
    HomeShell.tabIndex.removeListener(_alCambiarTab);
    _finanzas.removeListener(_mostrarBannerFacturas);
    super.dispose();
  }

  void _alCambiarTab() {
    if (mounted) setState(() {});
  }

  /// Al abrir la app, avisa una vez si hay facturas vencidas o que vencen hoy.
  void _mostrarBannerFacturas() {
    if (_bannerMostrado || _finanzas.cargando || !mounted) return;
    _bannerMostrado = true;

    var vencidas = 0;
    var venceHoy = 0;
    for (final factura in _finanzas.facturas) {
      final estado = estadoDeFactura(factura);
      if (estado == EstadoFactura.vencida) vencidas++;
      if (estado == EstadoFactura.venceHoy) venceHoy++;
    }
    if (vencidas == 0 && venceHoy == 0) return;

    final partes = [
      if (vencidas > 0) '$vencidas vencida${vencidas == 1 ? '' : 's'}',
      if (venceHoy > 0) '$venceHoy que vence${venceHoy == 1 ? '' : 'n'} hoy',
    ];

    mostrarBannerSuperior(
      context,
      titulo: 'Facturas por pagar',
      mensaje: 'Tienes ${partes.join(' y ')}. Toca para verlas.',
      icono: Icons.receipt_long,
      color: ColoresFinza.de(context).alerta,
      onTap: () => HomeShell.tabIndex.value = HomeShell.tabFacturas,
    );
  }

  Widget? _botonAgregar(int tab) {
    switch (tab) {
      case HomeShell.tabInicio:
      case HomeShell.tabMovimientos:
        return FloatingActionButton.extended(
          onPressed: () => abrirFormularioMovimiento(context),
          icon: const Icon(Icons.add),
          label: const Text('Agregar'),
        );
      case HomeShell.tabFacturas:
        if (context.watch<FinanzasProvider>().facturas.isEmpty) return null;
        return FloatingActionButton.extended(
          onPressed: () => abrirFormularioFactura(context),
          icon: const Icon(Icons.add),
          label: const Text('Factura'),
        );
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tab = HomeShell.tabIndex.value;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _titulos[tab],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          const _IconoSincronizacion(),
          IconButton(
            tooltip: 'Ajustes',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const AjustesScreen())),
          ),
        ],
      ),
      body: IndexedStack(
        index: tab,
        children: const [
          InicioScreen(),
          MovimientosScreen(),
          EstadisticasScreen(),
          FacturasScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => HomeShell.tabIndex.value = i,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.swap_vert_outlined),
            selectedIcon: Icon(Icons.swap_vert),
            label: 'Movimientos',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Estadísticas',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Facturas',
          ),
        ],
      ),
      floatingActionButton: _botonAgregar(tab),
    );
  }
}

/// Estado de la sincronización con Drive en la barra superior. Solo aparece
/// si hay una cuenta conectada.
class _IconoSincronizacion extends StatelessWidget {
  const _IconoSincronizacion();

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncService>();
    if (!sync.vinculado) return const SizedBox.shrink();

    if (sync.estado == EstadoSync.sincronizando) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final visual = estadoSyncVisual(context, sync);

    return IconButton(
      tooltip: visual.texto,
      icon: Icon(visual.icono, color: visual.color),
      onPressed: () =>
          Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const AjustesScreen())),
    );
  }
}
