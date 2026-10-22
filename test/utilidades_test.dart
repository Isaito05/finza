import 'package:finza/models/factura.dart';
import 'package:finza/models/filtro_movimientos.dart';
import 'package:finza/models/movimiento.dart';
import 'package:finza/utils/estado_factura.dart';
import 'package:finza/utils/fechas.dart';
import 'package:finza/utils/formato.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formato', () {
    test('formatearDinero usa formato colombiano', () {
      expect(formatearDinero(15000), '\$15.000,00');
      expect(formatearDinero(1500000.5), '\$1.500.000,50');
      expect(formatearDinero(-25000.75), '-\$25.000,75');
      expect(formatearDinero(0), '\$0,00');
    });

    test('leerMonto entiende lo que escribe el usuario', () {
      expect(leerMonto('80000'), 80000);
      expect(leerMonto('80.000'), 80000);
      expect(leerMonto('1.500.000'), 1500000);
      expect(leerMonto('80.000,50'), 80000.5);
      expect(leerMonto('80000,5'), 80000.5);
      expect(leerMonto('80000.50'), 80000.5);
      expect(leerMonto(' \$ 15.000 '), 15000);
      expect(leerMonto(''), isNull);
      expect(leerMonto('abc'), isNull);
    });

    test('montoParaEditar vuelve a un texto que leerMonto entiende', () {
      for (final monto in [80000.0, 80000.5, 0.25]) {
        expect(leerMonto(montoParaEditar(monto)), monto);
      }
    });
  });

  group('siguienteVencimiento', () {
    test('mensual conserva el día', () {
      expect(
        siguienteVencimiento(DateTime(2026, 3, 15), 'Mensual'),
        DateTime(2026, 4, 15),
      );
    });

    test('mensual ajusta al último día del mes', () {
      expect(
        siguienteVencimiento(DateTime(2026, 1, 31), 'Mensual'),
        DateTime(2026, 2, 28),
      );
      expect(
        siguienteVencimiento(DateTime(2028, 1, 31), 'Mensual'),
        DateTime(2028, 2, 29),
      );
    });

    test('cruza el año', () {
      expect(
        siguienteVencimiento(DateTime(2026, 12, 10), 'Mensual'),
        DateTime(2027, 1, 10),
      );
      expect(
        siguienteVencimiento(DateTime(2026, 11, 30), 'Trimestral'),
        DateTime(2027, 2, 28),
      );
    });

    test('semanal y anual', () {
      expect(
        siguienteVencimiento(DateTime(2026, 12, 29), 'Semanal'),
        DateTime(2027, 1, 5),
      );
      expect(
        siguienteVencimiento(DateTime(2028, 2, 29), 'Anual'),
        DateTime(2029, 2, 28),
      );
    });
  });

  group('estadoDeFactura', () {
    final hoy = DateTime(2026, 10, 22, 15);

    Factura factura(DateTime vence, {String estado = 'Pendiente'}) => Factura(
      nombre: 'Internet',
      categoria: 'Internet',
      monto: 80000,
      fechaVencimiento: vence,
      recurrente: false,
      estado: estado,
    );

    test('según la fecha', () {
      expect(
        estadoDeFactura(factura(DateTime(2026, 10, 21)), hoy: hoy),
        EstadoFactura.vencida,
      );
      expect(
        estadoDeFactura(factura(DateTime(2026, 10, 22)), hoy: hoy),
        EstadoFactura.venceHoy,
      );
      expect(
        estadoDeFactura(factura(DateTime(2026, 10, 25)), hoy: hoy),
        EstadoFactura.proxima,
      );
      expect(
        estadoDeFactura(factura(DateTime(2026, 10, 26)), hoy: hoy),
        EstadoFactura.pendiente,
      );
    });

    test('pagada aunque esté vencida', () {
      expect(
        estadoDeFactura(
          factura(DateTime(2026, 1, 1), estado: 'Pagada'),
          hoy: hoy,
        ),
        EstadoFactura.pagada,
      );
    });
  });

  group('FiltroMovimientos', () {
    final movimientos = [
      Movimiento(
        tipo: 'Ingreso',
        categoria: 'Salario',
        descripcion: 'Pago',
        monto: 2000000,
        fecha: DateTime(2026, 10, 1),
      ),
      Movimiento(
        tipo: 'Gasto',
        categoria: 'Alimentación',
        descripcion: 'Almuerzo',
        monto: 15000,
        fecha: DateTime(2026, 10, 20),
      ),
      Movimiento(
        tipo: 'Gasto',
        categoria: 'Transporte',
        descripcion: 'Bus',
        monto: 3000,
        fecha: DateTime(2026, 9, 30, 23),
      ),
    ];

    test('por tipo, categoría y búsqueda', () {
      expect(
        const FiltroMovimientos(tipo: 'Gasto').aplicar(movimientos),
        hasLength(2),
      );
      expect(
        const FiltroMovimientos(categorias: {'Transporte'})
            .aplicar(movimientos)
            .single
            .descripcion,
        'Bus',
      );
      expect(
        const FiltroMovimientos().aplicar(movimientos, busqueda: 'ALMU'),
        hasLength(1),
      );
    });

    test('por periodo personalizado incluye el último día completo', () {
      final filtro = FiltroMovimientos(
        periodo: PeriodoFiltro.personalizado,
        desde: DateTime(2026, 9, 30),
        hasta: DateTime(2026, 10, 1),
      );
      expect(filtro.aplicar(movimientos).map((m) => m.descripcion), [
        'Pago',
        'Bus',
      ]);
    });

    test('ordena por monto', () {
      final filtro = const FiltroMovimientos(orden: OrdenMovimientos.montoAsc);
      expect(filtro.aplicar(movimientos).map((m) => m.monto), [
        3000,
        15000,
        2000000,
      ]);
    });

    test('se guarda y se lee igual', () {
      final filtro = FiltroMovimientos(
        tipo: 'Gasto',
        periodo: PeriodoFiltro.personalizado,
        desde: DateTime(2026, 1, 1),
        hasta: DateTime(2026, 1, 31),
        categorias: const {'Transporte'},
        orden: OrdenMovimientos.montoDesc,
      );
      final leido = FiltroMovimientos.fromJson(filtro.toJson());
      expect(leido.toJson(), filtro.toJson());
    });
  });
}
