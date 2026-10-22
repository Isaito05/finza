import 'package:finza/services/sincronizacion.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> registro(
  String uuid,
  String actualizadoEn, {
  String? valor,
}) => {'uuid': uuid, 'actualizadoEn': actualizadoEn, 'valor': valor ?? uuid};

void main() {
  group('combinarRegistros', () {
    test('une lo que solo existe en cada lado', () {
      final resultado = combinarRegistros(
        [registro('a', '2026-01-01T10:00:00')],
        [registro('b', '2026-01-01T10:00:00')],
      );

      expect(
        resultado.combinados.map((r) => r['uuid']),
        unorderedEquals(['a', 'b']),
      );
      expect(resultado.paraAplicarLocal.map((r) => r['uuid']), ['b']);
      expect(resultado.hayQueSubir, isTrue);
    });

    test('gana la versión más reciente de cada registro', () {
      final resultado = combinarRegistros(
        [
          registro('a', '2026-01-02T10:00:00', valor: 'local nuevo'),
          registro('b', '2026-01-01T10:00:00', valor: 'local viejo'),
        ],
        [
          registro('a', '2026-01-01T10:00:00', valor: 'remoto viejo'),
          registro('b', '2026-01-03T10:00:00', valor: 'remoto nuevo'),
        ],
      );

      final porUuid = {
        for (final r in resultado.combinados) r['uuid']: r['valor'],
      };
      expect(porUuid, {'a': 'local nuevo', 'b': 'remoto nuevo'});
      expect(resultado.paraAplicarLocal.map((r) => r['valor']), [
        'remoto nuevo',
      ]);
      expect(resultado.hayQueSubir, isTrue);
    });

    test('compara instantes aunque vengan en zonas horarias distintas', () {
      // 10:30 en Bogotá (UTC-5) es 15:30 UTC: más reciente que 15:00 UTC.
      final resultado = combinarRegistros(
        [registro('a', '2026-03-01T15:00:00Z', valor: 'utc')],
        [registro('a', '2026-03-01T10:30:00-05:00', valor: 'bogota')],
      );
      expect(resultado.combinados.single['valor'], 'bogota');
    });

    test('sin cambios no aplica ni sube nada', () {
      final datos = [registro('a', '2026-01-01T10:00:00')];
      final resultado = combinarRegistros(datos, [...datos]);

      expect(resultado.paraAplicarLocal, isEmpty);
      expect(resultado.hayQueSubir, isFalse);
    });

    test('un borrado más reciente en Drive se aplica acá', () {
      final borrado = {
        ...registro('a', '2026-01-05T10:00:00'),
        'eliminadoEn': '2026-01-05T10:00:00',
      };
      final resultado = combinarRegistros(
        [registro('a', '2026-01-01T10:00:00')],
        [borrado],
      );

      expect(resultado.paraAplicarLocal.single['eliminadoEn'], isNotNull);
      expect(resultado.hayQueSubir, isFalse);
    });

    test('el teléfono sin datos recibe todo y no sube nada', () {
      final resultado = combinarRegistros([], [
        registro('a', '2026-01-01T10:00:00'),
        registro('b', '2026-01-01T10:00:00'),
      ]);

      expect(resultado.paraAplicarLocal, hasLength(2));
      expect(resultado.hayQueSubir, isFalse);
    });
  });

  test('detecta archivos de una versión más nueva de la app', () {
    final archivo = ArchivoSincronizacion.fromJson({
      'formato': formatoArchivo + 1,
      'movimientos': [],
      'facturas': [],
    });
    expect(archivo.esDeUnaVersionMasNueva, isTrue);
  });
}
