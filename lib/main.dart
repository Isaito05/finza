import 'package:flutter/material.dart';

import 'database/database_helper.dart';
import 'models/movimiento.dart';
import 'models/factura.dart';

void main() {
  runApp(const FinzaApp());
}

class FinzaApp extends StatelessWidget {
  const FinzaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Finza',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.green,
        scaffoldBackgroundColor: const Color(0xFFF5F7F5),
      ),
      home: const InicioScreen(),
    );
  }
}

class InicioScreen extends StatefulWidget {
  const InicioScreen({super.key});

  @override
  State<InicioScreen> createState() => _InicioScreenState();
}

class _InicioScreenState extends State<InicioScreen> {
  int _paginaActual = 0;

  List<Movimiento> _movimientos = [];
  List<Factura> _facturas = [];

  bool _cargando = true;
  String _filtroTipo = 'Todos';
  String _textoBusqueda = '';

  @override
  void initState() {
    super.initState();
    _cargarMovimientos();
    _cargarFacturas();
  }

  Future<void> _cargarMovimientos() async {
    final movimientos = await DatabaseHelper.instance.obtenerMovimientos();

    if (!mounted) return;

    setState(() {
      _movimientos = movimientos;
      _cargando = false;
    });
  }

  Future<void> _cargarFacturas() async {
    final facturas = await DatabaseHelper.instance.obtenerFacturas();

    if (!mounted) return;

    setState(() {
      _facturas = facturas;
    });
  }

  double get totalIngresos {
    return _movimientos
        .where((movimiento) => movimiento.tipo == 'Ingreso')
        .fold(0, (total, movimiento) => total + movimiento.monto);
  }

  double get totalGastos {
    return _movimientos
        .where((movimiento) => movimiento.tipo == 'Gasto')
        .fold(0, (total, movimiento) => total + movimiento.monto);
  }

  double get saldo {
    return totalIngresos - totalGastos;
  }

  String _formatearDinero(double valor) {
    final partes = valor.toStringAsFixed(2).split('.');

    final parteEntera = partes[0];
    final parteDecimal = partes[1];

    final enteroFormateado = parteEntera.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => '.',
    );

    return '\$$enteroFormateado,$parteDecimal';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Finza',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
      ),
      body: _construirPagina(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _paginaActual,
        onDestinationSelected: (index) {
          setState(() {
            _paginaActual = index;
          });
        },
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
      floatingActionButton: _paginaActual == 0
          ? FloatingActionButton.extended(
              onPressed: _mostrarDialogoMovimiento,
              icon: const Icon(Icons.add),
              label: const Text('Agregar'),
            )
          : null,
    );
  }

  Widget _construirPagina() {
    switch (_paginaActual) {
      case 1:
        return _pantallaMovimientos();

      case 2:
        return _pantallaEstadisticas();

      case 3:
        return _pantallaFacturas();

      default:
        return _pantallaInicio();
    }
  }

  Widget _pantallaInicio() {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _cargarMovimientos,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _tarjetaSaldo(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _tarjetaResumen(
                  titulo: 'Ingresos',
                  valor: totalIngresos,
                  icono: Icons.arrow_downward,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _tarjetaResumen(
                  titulo: 'Gastos',
                  valor: totalGastos,
                  icono: Icons.arrow_upward,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Movimientos recientes',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          _listaMovimientos(limite: 5),
        ],
      ),
    );
  }

  Widget _tarjetaSaldo() {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Saldo disponible', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              _formatearDinero(saldo),
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tarjetaResumen({
    required String titulo,
    required double valor,
    required IconData icono,
  }) {
    final esIngreso = titulo == 'Ingresos';

    final color = esIngreso ? Colors.green : Colors.red;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icono, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              titulo,
              style: TextStyle(fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 4),
            Text(
              _formatearDinero(valor),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pantallaMovimientos() {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    final movimientosFiltrados = _movimientos.where((movimiento) {
      final coincideTipo =
          _filtroTipo == 'Todos' || movimiento.tipo == _filtroTipo;

      final texto = _textoBusqueda.toLowerCase();

      final coincideBusqueda =
          movimiento.descripcion.toLowerCase().contains(texto) ||
          movimiento.categoria.toLowerCase().contains(texto);

      return coincideTipo && coincideBusqueda;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Movimientos',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),

              const SizedBox(height: 16),

              TextField(
                decoration: InputDecoration(
                  hintText: 'Buscar movimiento...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _textoBusqueda.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _textoBusqueda = '';
                            });
                          },
                        )
                      : null,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (valor) {
                  setState(() {
                    _textoBusqueda = valor;
                  });
                },
              ),

              const SizedBox(height: 12),

              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _botonFiltro('Todos'),
                    const SizedBox(width: 8),
                    _botonFiltro('Ingreso'),
                    const SizedBox(width: 8),
                    _botonFiltro('Gasto'),
                  ],
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: RefreshIndicator(
            onRefresh: _cargarMovimientos,
            child: movimientosFiltrados.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      const SizedBox(height: 40),
                      Icon(
                        Icons.search_off,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      const Center(
                        child: Text(
                          'No se encontraron movimientos.',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Center(
                        child: Text(
                          'Prueba con otro término o filtro.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: movimientosFiltrados.length,
                    itemBuilder: (context, index) {
                      return _tarjetaMovimiento(movimientosFiltrados[index]);
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _botonFiltro(String filtro) {
    final seleccionado = _filtroTipo == filtro;

    return FilterChip(
      label: Text(
        filtro == 'Todos'
            ? 'Todos'
            : filtro == 'Ingreso'
            ? 'Ingresos'
            : 'Gastos',
      ),
      selected: seleccionado,
      onSelected: (_) {
        setState(() {
          _filtroTipo = filtro;
        });
      },
    );
  }

  Widget _tarjetaMovimiento(Movimiento movimiento) {
    final esIngreso = movimiento.tipo == 'Ingreso';

    final fecha =
        '${movimiento.fecha.day.toString().padLeft(2, '0')}/'
        '${movimiento.fecha.month.toString().padLeft(2, '0')}/'
        '${movimiento.fecha.year}';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          child: Icon(esIngreso ? Icons.arrow_downward : Icons.arrow_upward),
        ),
        title: Text(
          movimiento.descripcion,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('${movimiento.categoria} • $fecha'),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${esIngreso ? '+' : '-'}${_formatearDinero(movimiento.monto)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: esIngreso ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(height: 4),
            const Icon(Icons.more_horiz, size: 20),
          ],
        ),
        onTap: () {
          _mostrarOpcionesMovimiento(movimiento);
        },
      ),
    );
  }

  Widget _listaMovimientos({int? limite}) {
    if (_movimientos.isEmpty) {
      return const Card(
        elevation: 0,
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.account_balance_wallet_outlined, size: 50),
              SizedBox(height: 12),
              Text(
                'Todavía no tienes movimientos.',
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 4),
              Text(
                'Agrega tu primer ingreso o gasto.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final lista = limite == null
        ? _movimientos
        : _movimientos.take(limite).toList();

    return Column(
      children: lista.map((movimiento) {
        final esIngreso = movimiento.tipo == 'Ingreso';

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              child: Icon(
                esIngreso ? Icons.arrow_downward : Icons.arrow_upward,
              ),
            ),
            title: Text(
              movimiento.descripcion,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${movimiento.categoria} • ${movimiento.fecha.day}/${movimiento.fecha.month}/${movimiento.fecha.year}',
            ),
            trailing: Text(
              '${esIngreso ? '+' : '-'}${_formatearDinero(movimiento.monto)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: esIngreso ? Colors.green : Colors.red,
              ),
            ),
            onLongPress: () {
              _mostrarOpcionesMovimiento(movimiento);
            },
          ),
        );
      }).toList(),
    );
  }

  Widget _pantallaEstadisticas() {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    final ingresos = _movimientos
        .where((movimiento) => movimiento.tipo == 'Ingreso')
        .toList();

    final gastos = _movimientos
        .where((movimiento) => movimiento.tipo == 'Gasto')
        .toList();

    final totalIngresosEstadistica = ingresos.fold<double>(
      0,
      (total, movimiento) => total + movimiento.monto,
    );

    final totalGastosEstadistica = gastos.fold<double>(
      0,
      (total, movimiento) => total + movimiento.monto,
    );

    final totalGeneral = totalIngresosEstadistica + totalGastosEstadistica;

    final porcentajeIngresos = totalGeneral == 0
        ? 0.0
        : totalIngresosEstadistica / totalGeneral;

    final porcentajeGastos = totalGeneral == 0
        ? 0.0
        : totalGastosEstadistica / totalGeneral;

    final Map<String, double> gastosPorCategoria = {};

    for (final movimiento in gastos) {
      gastosPorCategoria[movimiento.categoria] =
          (gastosPorCategoria[movimiento.categoria] ?? 0) + movimiento.monto;
    }

    final categoriasOrdenadas = gastosPorCategoria.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return RefreshIndicator(
      onRefresh: _cargarMovimientos,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          const Text(
            'Estadísticas',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 20),

          // RESUMEN
          Row(
            children: [
              Expanded(
                child: _tarjetaEstadistica(
                  titulo: 'Ingresos',
                  valor: totalIngresosEstadistica,
                  icono: Icons.arrow_downward,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _tarjetaEstadistica(
                  titulo: 'Gastos',
                  valor: totalGastosEstadistica,
                  icono: Icons.arrow_upward,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Saldo actual', style: TextStyle(fontSize: 15)),
                  const SizedBox(height: 6),
                  Text(
                    _formatearDinero(saldo),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // INGRESOS VS GASTOS
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ingresos vs. gastos',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 20),

                  const Text('Ingresos'),

                  const SizedBox(height: 6),

                  LinearProgressIndicator(
                    value: porcentajeIngresos,
                    minHeight: 10,
                    color: Colors.green,
                  ),

                  const SizedBox(height: 16),

                  const Text('Gastos'),

                  const SizedBox(height: 6),

                  LinearProgressIndicator(
                    value: porcentajeGastos,
                    minHeight: 10,
                    color: Colors.red,
                  ),

                  const SizedBox(height: 16),

                  Text(
                    'Total de movimientos: ${_movimientos.length}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // GASTOS POR CATEGORÍA
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Gastos por categoría',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 16),

                  if (categoriasOrdenadas.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Text('Todavía no tienes gastos registrados.'),
                      ),
                    )
                  else
                    ...categoriasOrdenadas.map((entrada) {
                      final porcentaje = totalGastosEstadistica == 0
                          ? 0.0
                          : entrada.value / totalGastosEstadistica;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  entrada.key,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  _formatearDinero(entrada.value),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 7),

                            LinearProgressIndicator(
                              value: porcentaje,
                              minHeight: 8,
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaEstadistica({
    required String titulo,
    required double valor,
    required IconData icono,
  }) {
    final esIngreso = titulo == 'Ingresos';

    final color = esIngreso ? Colors.green : Colors.red;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, color: color, size: 28),
            const SizedBox(height: 10),
            Text(
              titulo,
              style: TextStyle(fontWeight: FontWeight.w600, color: color),
            ),
            const SizedBox(height: 6),
            Text(
              _formatearDinero(valor),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pantallaFacturas() {
    if (_facturas.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.receipt_long, size: 70),
              const SizedBox(height: 16),
              const Text(
                'No tienes facturas',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Agrega tu primera factura para comenzar a controlar tus pagos.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _agregarFactura,
                icon: const Icon(Icons.add),
                label: const Text('Agregar factura'),
              ),
            ],
          ),
        ),
      );
    }

    final facturasPendientes = _facturas
        .where((factura) => factura.estado != 'Pagada')
        .toList();

    final facturasPagadas = _facturas
        .where((factura) => factura.estado == 'Pagada')
        .toList();

    final totalPendiente = facturasPendientes.fold<double>(
      0,
      (total, factura) => total + factura.monto,
    );

    return RefreshIndicator(
      onRefresh: _cargarFacturas,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Facturas',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              IconButton(
                onPressed: _agregarFactura,
                icon: const Icon(Icons.add),
                tooltip: 'Agregar factura',
              ),
            ],
          ),

          const SizedBox(height: 16),

          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const CircleAvatar(child: Icon(Icons.account_balance_wallet)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total pendiente',
                          style: TextStyle(fontSize: 15),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _formatearDinero(totalPendiente),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      Text(
                        '${facturasPendientes.length}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text('pendientes'),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          if (facturasPendientes.isNotEmpty) ...[
            const Text(
              'Pendientes',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            ...facturasPendientes.map((factura) => _tarjetaFactura(factura)),
          ],

          if (facturasPagadas.isNotEmpty) ...[
            const SizedBox(height: 16),

            const Text(
              'Pagadas',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            ...facturasPagadas.map((factura) => _tarjetaFactura(factura)),
          ],
        ],
      ),
    );
  }

  Widget _tarjetaFactura(Factura factura) {
    final estado = _obtenerEstadoFactura(factura);

    Color colorEstado;
    IconData iconoEstado;
    String textoEstado;

    switch (estado) {
      case 'Pagada':
        colorEstado = Colors.green;
        iconoEstado = Icons.check_circle;
        textoEstado = 'Pagada';
        break;

      case 'Vencida':
        colorEstado = Colors.red;
        iconoEstado = Icons.warning;
        textoEstado = 'Vencida';
        break;

      case 'Vence hoy':
        colorEstado = Colors.orange;
        iconoEstado = Icons.today;
        textoEstado = 'Vence hoy';
        break;

      case 'Próxima':
        colorEstado = Colors.orange;
        iconoEstado = Icons.schedule;
        textoEstado = 'Próxima a vencer';
        break;

      default:
        colorEstado = Colors.red;
        iconoEstado = Icons.pending;
        textoEstado = 'Pendiente';
    }

    final fecha =
        '${factura.fechaVencimiento.day.toString().padLeft(2, '0')}/'
        '${factura.fechaVencimiento.month.toString().padLeft(2, '0')}/'
        '${factura.fechaVencimiento.year}';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(child: Icon(iconoEstado, color: colorEstado)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        factura.nombre,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(factura.categoria),
                    ],
                  ),
                ),
                Text(
                  _formatearDinero(factura.monto),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colorEstado,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            Row(
              children: [
                Icon(
                  Icons.calendar_month,
                  size: 18,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 6),
                Text('Vence: $fecha'),
              ],
            ),

            if (factura.recurrente) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.repeat, size: 18, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Text('Pago ${factura.frecuencia?.toLowerCase()}'),
                ],
              ),
            ],

            const SizedBox(height: 14),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colorEstado.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    textoEstado,
                    style: TextStyle(
                      color: colorEstado,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                if (factura.estado != 'Pagada')
                  OutlinedButton.icon(
                    onPressed: () {
                      _marcarFacturaComoPagada(factura);
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('Marcar pagada'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _obtenerEstadoFactura(Factura factura) {
    if (factura.estado == 'Pagada') {
      return 'Pagada';
    }

    final ahora = DateTime.now();

    final hoy = DateTime(ahora.year, ahora.month, ahora.day);

    final vencimiento = DateTime(
      factura.fechaVencimiento.year,
      factura.fechaVencimiento.month,
      factura.fechaVencimiento.day,
    );

    final diferencia = vencimiento.difference(hoy).inDays;

    if (diferencia < 0) {
      return 'Vencida';
    }

    if (diferencia == 0) {
      return 'Vence hoy';
    }

    if (diferencia <= 3) {
      return 'Próxima';
    }

    return 'Pendiente';
  }

  Future<void> _marcarFacturaComoPagada(Factura factura) async {
    final facturaActualizada = Factura(
      id: factura.id,
      nombre: factura.nombre,
      categoria: factura.categoria,
      monto: factura.monto,
      fechaVencimiento: factura.fechaVencimiento,
      recurrente: factura.recurrente,
      frecuencia: factura.frecuencia,
      estado: 'Pagada',
    );

    await DatabaseHelper.instance.actualizarFactura(facturaActualizada);

    await _cargarFacturas();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Factura marcada como pagada.')),
    );
  }

  Future<void> _agregarFactura() async {
    final resultado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (context) => const AgregarFacturaScreen()),
    );

    if (resultado == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Factura guardada correctamente.')),
      );
    }
  }

  Future<void> _mostrarDialogoMovimiento() async {
    final resultado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (context) => const AgregarMovimientoScreen()),
    );

    if (resultado == true && mounted) {
      await _cargarMovimientos();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Movimiento guardado correctamente.')),
      );
    }
  }

  Future<void> _mostrarOpcionesMovimiento(Movimiento movimiento) async {
    await showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Eliminar movimiento'),
                onTap: () async {
                  Navigator.pop(context);

                  if (movimiento.id != null) {
                    await DatabaseHelper.instance.eliminarMovimiento(
                      movimiento.id!,
                    );

                    await _cargarMovimientos();
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _mostrarMensajeProximamente() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('La sección de facturas la construiremos próximamente.'),
      ),
    );
  }
}

class AgregarMovimientoScreen extends StatefulWidget {
  const AgregarMovimientoScreen({super.key});

  @override
  State<AgregarMovimientoScreen> createState() =>
      _AgregarMovimientoScreenState();
}

class _AgregarMovimientoScreenState extends State<AgregarMovimientoScreen> {
  final descripcionController = TextEditingController();
  final montoController = TextEditingController();

  String tipo = 'Ingreso';
  String categoria = 'Salario';

  List<String> get categorias {
    if (tipo == 'Ingreso') {
      return ['Salario', 'Freelance', 'Negocio', 'Otros'];
    }

    return [
      'Alimentación',
      'Transporte',
      'Vivienda',
      'Servicios',
      'Entretenimiento',
      'Otros',
    ];
  }

  @override
  void dispose() {
    descripcionController.dispose();
    montoController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final descripcion = descripcionController.text.trim();

    final monto = double.tryParse(
      montoController.text.trim().replaceAll(',', '.'),
    );

    if (descripcion.isEmpty || monto == null || monto <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completa la descripción y coloca un monto válido.'),
        ),
      );
      return;
    }

    final movimiento = Movimiento(
      tipo: tipo,
      categoria: categoria,
      descripcion: descripcion,
      monto: monto,
      fecha: DateTime.now(),
    );

    await DatabaseHelper.instance.insertarMovimiento(movimiento);

    if (!mounted) return;

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo movimiento')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Tipo de movimiento',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 12),

              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'Ingreso',
                    label: Text('Ingreso'),
                    icon: Icon(Icons.arrow_downward),
                  ),
                  ButtonSegment(
                    value: 'Gasto',
                    label: Text('Gasto'),
                    icon: Icon(Icons.arrow_upward),
                  ),
                ],
                selected: {tipo},
                onSelectionChanged: (seleccion) {
                  setState(() {
                    tipo = seleccion.first;

                    categoria = tipo == 'Ingreso' ? 'Salario' : 'Alimentación';
                  });
                },
              ),

              const SizedBox(height: 24),

              DropdownButtonFormField<String>(
                initialValue: categoria,
                decoration: const InputDecoration(
                  labelText: 'Categoría',
                  border: OutlineInputBorder(),
                ),
                items: categorias.map((item) {
                  return DropdownMenuItem<String>(
                    value: item,
                    child: Text(item),
                  );
                }).toList(),
                onChanged: (valor) {
                  if (valor != null) {
                    setState(() {
                      categoria = valor;
                    });
                  }
                },
              ),

              const SizedBox(height: 16),

              TextField(
                controller: descripcionController,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  hintText: 'Ej. Almuerzo',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 16),

              TextField(
                controller: montoController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Monto',
                  prefixText: '\$ ',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 28),

              FilledButton.icon(
                onPressed: _guardar,
                icon: const Icon(Icons.save),
                label: const Text('Guardar movimiento'),
              ),

              const SizedBox(height: 12),

              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).pop(false);
                },
                child: const Text('Cancelar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AgregarFacturaScreen extends StatefulWidget {
  const AgregarFacturaScreen({super.key});

  @override
  State<AgregarFacturaScreen> createState() => _AgregarFacturaScreenState();
}

class _AgregarFacturaScreenState extends State<AgregarFacturaScreen> {
  final nombreController = TextEditingController();
  final montoController = TextEditingController();

  String categoria = 'Servicios';
  bool recurrente = false;
  String frecuencia = 'Mensual';

  DateTime fechaVencimiento = DateTime.now();

  final categorias = [
    'Servicios',
    'Vivienda',
    'Internet',
    'Telefonía',
    'Suscripciones',
    'Transporte',
    'Otros',
  ];

  final frecuencias = ['Semanal', 'Mensual', 'Trimestral', 'Anual'];

  @override
  void dispose() {
    nombreController.dispose();
    montoController.dispose();
    super.dispose();
  }

  Future<void> _seleccionarFecha() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: fechaVencimiento,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (fecha != null && mounted) {
      setState(() {
        fechaVencimiento = fecha;
      });
    }
  }

  Future<void> _guardar() async {
    final nombre = nombreController.text.trim();

    final monto = double.tryParse(
      montoController.text.trim().replaceAll(',', '.'),
    );

    if (nombre.isEmpty || monto == null || monto <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completa el nombre y coloca un monto válido.'),
        ),
      );
      return;
    }

    final factura = Factura(
      nombre: nombre,
      categoria: categoria,
      monto: monto,
      fechaVencimiento: fechaVencimiento,
      recurrente: recurrente,
      frecuencia: recurrente ? frecuencia : null,
      estado: 'Pendiente',
    );

    await DatabaseHelper.instance.insertarFactura(factura);

    if (!mounted) return;

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final fecha =
        '${fechaVencimiento.day.toString().padLeft(2, '0')}/'
        '${fechaVencimiento.month.toString().padLeft(2, '0')}/'
        '${fechaVencimiento.year}';

    return Scaffold(
      appBar: AppBar(title: const Text('Nueva factura')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: nombreController,
                decoration: const InputDecoration(
                  labelText: 'Nombre de la factura',
                  hintText: 'Ej. Internet',
                  prefixIcon: Icon(Icons.receipt_long),
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                initialValue: categoria,
                decoration: const InputDecoration(
                  labelText: 'Categoría',
                  prefixIcon: Icon(Icons.category_outlined),
                  border: OutlineInputBorder(),
                ),
                items: categorias.map((item) {
                  return DropdownMenuItem<String>(
                    value: item,
                    child: Text(item),
                  );
                }).toList(),
                onChanged: (valor) {
                  if (valor != null) {
                    setState(() {
                      categoria = valor;
                    });
                  }
                },
              ),

              const SizedBox(height: 16),

              TextField(
                controller: montoController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Monto',
                  hintText: 'Ej. 80000',
                  prefixText: '\$ ',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 16),

              InkWell(
                onTap: _seleccionarFecha,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Fecha de vencimiento',
                    prefixIcon: Icon(Icons.calendar_month),
                    border: OutlineInputBorder(),
                  ),
                  child: Text(fecha),
                ),
              ),

              const SizedBox(height: 20),

              Card(
                elevation: 0,
                child: SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  title: const Text(
                    'Pago recurrente',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('Se repite automáticamente'),
                  value: recurrente,
                  onChanged: (valor) {
                    setState(() {
                      recurrente = valor;
                    });
                  },
                ),
              ),

              if (recurrente) ...[
                const SizedBox(height: 12),

                DropdownButtonFormField<String>(
                  initialValue: frecuencia,
                  decoration: const InputDecoration(
                    labelText: 'Frecuencia',
                    prefixIcon: Icon(Icons.repeat),
                    border: OutlineInputBorder(),
                  ),
                  items: frecuencias.map((item) {
                    return DropdownMenuItem<String>(
                      value: item,
                      child: Text(item),
                    );
                  }).toList(),
                  onChanged: (valor) {
                    if (valor != null) {
                      setState(() {
                        frecuencia = valor;
                      });
                    }
                  },
                ),
              ],

              const SizedBox(height: 28),

              FilledButton.icon(
                onPressed: _guardar,
                icon: const Icon(Icons.save),
                label: const Text('Guardar factura'),
              ),

              const SizedBox(height: 12),

              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).pop(false);
                },
                child: const Text('Cancelar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
