import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/categorias.dart';
import '../models/movimiento.dart';
import '../providers/finanzas_provider.dart';
import '../utils/fechas.dart';
import '../utils/formato.dart';

/// Crear (sin [movimiento]) o editar (con [movimiento]) un movimiento.
class MovimientoFormScreen extends StatefulWidget {
  const MovimientoFormScreen({super.key, this.movimiento});

  final Movimiento? movimiento;

  @override
  State<MovimientoFormScreen> createState() => _MovimientoFormScreenState();
}

class _MovimientoFormScreenState extends State<MovimientoFormScreen> {
  late final _descripcionController = TextEditingController(
    text: widget.movimiento?.descripcion,
  );
  late final _montoController = TextEditingController(
    text: widget.movimiento == null
        ? null
        : montoParaEditar(widget.movimiento!.monto),
  );

  late String _tipo = widget.movimiento?.tipo ?? 'Ingreso';
  late String _categoria =
      widget.movimiento?.categoria ?? Categorias.deMovimiento(_tipo).first;
  late DateTime _fecha = widget.movimiento?.fecha ?? DateTime.now();

  bool _guardando = false;

  bool get _editando => widget.movimiento != null;

  List<String> get _categorias {
    final categorias = Categorias.deMovimiento(_tipo);
    // Si se renombró una categoría, la del movimiento sigue disponible.
    if (!categorias.contains(_categoria)) return [...categorias, _categoria];
    return categorias;
  }

  @override
  void dispose() {
    _descripcionController.dispose();
    _montoController.dispose();
    super.dispose();
  }

  Future<void> _seleccionarFecha() async {
    final hoy = DateTime.now();
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2000),
      lastDate: DateTime(hoy.year + 1, 12, 31),
    );

    if (fecha != null && mounted) {
      setState(() {
        // Se conserva la hora original para no desordenar los del mismo día.
        _fecha = DateTime(
          fecha.year,
          fecha.month,
          fecha.day,
          _fecha.hour,
          _fecha.minute,
          _fecha.second,
        );
      });
    }
  }

  Future<void> _guardar() async {
    final descripcion = _descripcionController.text.trim();
    final monto = leerMonto(_montoController.text);

    if (descripcion.isEmpty || monto == null || monto <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completa la descripción y coloca un monto válido.'),
        ),
      );
      return;
    }

    setState(() => _guardando = true);

    final base =
        widget.movimiento ??
        Movimiento(
          tipo: _tipo,
          categoria: _categoria,
          descripcion: descripcion,
          monto: monto,
          fecha: _fecha,
        );

    await context.read<FinanzasProvider>().guardarMovimiento(
      base.copyWith(
        tipo: _tipo,
        categoria: _categoria,
        descripcion: descripcion,
        monto: monto,
        fecha: _fecha,
      ),
    );

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final esHoy = soloFecha(_fecha) == soloFecha(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: Text(_editando ? 'Editar movimiento' : 'Nuevo movimiento'),
      ),
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
                selected: {_tipo},
                onSelectionChanged: (seleccion) {
                  setState(() {
                    _tipo = seleccion.first;
                    _categoria = Categorias.deMovimiento(_tipo).first;
                  });
                },
              ),
              const SizedBox(height: 24),
              DropdownButtonFormField<String>(
                key: ValueKey(_tipo),
                initialValue: _categoria,
                decoration: const InputDecoration(labelText: 'Categoría'),
                items: _categorias
                    .map(
                      (item) =>
                          DropdownMenuItem(value: item, child: Text(item)),
                    )
                    .toList(),
                onChanged: (valor) {
                  if (valor != null) setState(() => _categoria = valor);
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descripcionController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  hintText: 'Ej. Almuerzo',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _montoController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Monto',
                  hintText: 'Ej. 15000',
                  prefixText: '\$ ',
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _seleccionarFecha,
                borderRadius: BorderRadius.circular(4),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Fecha',
                    prefixIcon: Icon(Icons.calendar_month),
                  ),
                  child: Text(
                    esHoy
                        ? 'Hoy, ${formatearFecha(_fecha)}'
                        : formatearFecha(_fecha),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: _guardando ? null : _guardar,
                icon: const Icon(Icons.save),
                label: Text(
                  _editando ? 'Guardar cambios' : 'Guardar movimiento',
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
