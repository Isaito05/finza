import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/categorias.dart';
import '../models/factura.dart';
import '../providers/finanzas_provider.dart';
import '../utils/fechas.dart';
import '../utils/formato.dart';

/// Crear (sin [factura]) o editar (con [factura]) una factura.
class FacturaFormScreen extends StatefulWidget {
  const FacturaFormScreen({super.key, this.factura});

  final Factura? factura;

  @override
  State<FacturaFormScreen> createState() => _FacturaFormScreenState();
}

class _FacturaFormScreenState extends State<FacturaFormScreen> {
  late final _nombreController = TextEditingController(
    text: widget.factura?.nombre,
  );
  late final _montoController = TextEditingController(
    text: widget.factura == null
        ? null
        : montoParaEditar(widget.factura!.monto),
  );

  late String _categoria =
      widget.factura?.categoria ?? Categorias.facturas.first;
  late bool _recurrente = widget.factura?.recurrente ?? false;
  late String _frecuencia = widget.factura?.frecuencia ?? 'Mensual';
  late DateTime _fechaVencimiento =
      widget.factura?.fechaVencimiento ?? soloFecha(DateTime.now());

  bool _guardando = false;

  bool get _editando => widget.factura != null;

  @override
  void dispose() {
    _nombreController.dispose();
    _montoController.dispose();
    super.dispose();
  }

  Future<void> _seleccionarFecha() async {
    // Al editar, la factura puede estar vencida (fecha anterior a hoy) y el
    // selector falla si `initialDate` es anterior a `firstDate`.
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaVencimiento,
      firstDate: _editando ? DateTime(2000) : soloFecha(DateTime.now()),
      lastDate: DateTime(2100),
    );

    if (fecha != null && mounted) {
      setState(() => _fechaVencimiento = fecha);
    }
  }

  Future<void> _guardar() async {
    final nombre = _nombreController.text.trim();
    final monto = leerMonto(_montoController.text);

    if (nombre.isEmpty || monto == null || monto <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completa el nombre y coloca un monto válido.'),
        ),
      );
      return;
    }

    setState(() => _guardando = true);

    final base =
        widget.factura ??
        Factura(
          nombre: nombre,
          categoria: _categoria,
          monto: monto,
          fechaVencimiento: _fechaVencimiento,
          recurrente: _recurrente,
          estado: 'Pendiente',
        );

    await context.read<FinanzasProvider>().guardarFactura(
      base.copyWith(
        nombre: nombre,
        categoria: _categoria,
        monto: monto,
        fechaVencimiento: _fechaVencimiento,
        recurrente: _recurrente,
        frecuencia: _recurrente ? _frecuencia : null,
      ),
    );

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editando ? 'Editar factura' : 'Nueva factura'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _nombreController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nombre de la factura',
                  hintText: 'Ej. Internet',
                  prefixIcon: Icon(Icons.receipt_long),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _categoria,
                decoration: const InputDecoration(
                  labelText: 'Categoría',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: {...Categorias.facturas, _categoria}
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
                controller: _montoController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Monto',
                  hintText: 'Ej. 80000',
                  prefixText: '\$ ',
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _seleccionarFecha,
                borderRadius: BorderRadius.circular(4),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Fecha de vencimiento',
                    prefixIcon: Icon(Icons.calendar_month),
                  ),
                  child: Text(formatearFecha(_fechaVencimiento)),
                ),
              ),
              const SizedBox(height: 20),
              Card(
                child: SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  title: const Text(
                    'Pago recurrente',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'Al marcarla como pagada se crea la del siguiente periodo',
                  ),
                  value: _recurrente,
                  onChanged: (valor) => setState(() => _recurrente = valor),
                ),
              ),
              if (_recurrente) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _frecuencia,
                  decoration: const InputDecoration(
                    labelText: 'Frecuencia',
                    prefixIcon: Icon(Icons.repeat),
                  ),
                  items: Categorias.frecuencias
                      .map(
                        (item) =>
                            DropdownMenuItem(value: item, child: Text(item)),
                      )
                      .toList(),
                  onChanged: (valor) {
                    if (valor != null) setState(() => _frecuencia = valor);
                  },
                ),
              ],
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: _guardando ? null : _guardar,
                icon: const Icon(Icons.save),
                label: Text(_editando ? 'Guardar cambios' : 'Guardar factura'),
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
