/// Lógica de combinación de datos entre el teléfono y Drive, sin nada de
/// red ni base de datos para poder probarla con tests.
///
/// Cada registro (movimiento o factura) tiene un `uuid` y un `actualizadoEn`.
/// Al combinar, por cada `uuid` gana la versión con `actualizadoEn` más
/// reciente. Los borrados también son registros (`eliminadoEn` / `purgado`),
/// así que se propagan igual que una edición.
library;

/// Versión del formato del archivo en Drive. Si una versión futura de la app
/// lo cambia, las versiones viejas no lo pisan (ver [ArchivoSincronizacion]).
const formatoArchivo = 1;

class ResultadoCombinacion {
  ResultadoCombinacion({
    required this.combinados,
    required this.paraAplicarLocal,
    required this.hayQueSubir,
  });

  /// Todos los registros, con la versión ganadora de cada uno.
  final List<Map<String, dynamic>> combinados;

  /// Registros donde ganó la versión de Drive (o que solo existen allá).
  final List<Map<String, dynamic>> paraAplicarLocal;

  /// Hay registros donde ganó la versión local (o que solo existen acá).
  final bool hayQueSubir;
}

ResultadoCombinacion combinarRegistros(
  List<Map<String, dynamic>> locales,
  List<Map<String, dynamic>> remotos,
) {
  final porUuid = <String, Map<String, dynamic>>{
    for (final local in locales) local['uuid'] as String: local,
  };
  final paraAplicarLocal = <Map<String, dynamic>>[];
  final uuidsRemotos = <String>{};

  for (final remoto in remotos) {
    final uuid = remoto['uuid'] as String;
    uuidsRemotos.add(uuid);

    final local = porUuid[uuid];
    if (local == null || _fecha(remoto).isAfter(_fecha(local))) {
      porUuid[uuid] = remoto;
      paraAplicarLocal.add(remoto);
    }
  }

  final remotosPorUuid = {for (final r in remotos) r['uuid'] as String: r};
  final hayQueSubir = locales.any((local) {
    final remoto = remotosPorUuid[local['uuid']];
    return remoto == null || _fecha(local).isAfter(_fecha(remoto));
  });

  return ResultadoCombinacion(
    combinados: porUuid.values.toList(),
    paraAplicarLocal: paraAplicarLocal,
    hayQueSubir: hayQueSubir,
  );
}

DateTime _fecha(Map<String, dynamic> registro) =>
    DateTime.parse(registro['actualizadoEn'] as String);

/// Contenido del archivo `finza_datos.json` en Drive.
class ArchivoSincronizacion {
  ArchivoSincronizacion({
    required this.movimientos,
    required this.facturas,
    this.formato = formatoArchivo,
  });

  final int formato;
  final List<Map<String, dynamic>> movimientos;
  final List<Map<String, dynamic>> facturas;

  /// El archivo lo escribió una versión más nueva de Finza.
  bool get esDeUnaVersionMasNueva => formato > formatoArchivo;

  factory ArchivoSincronizacion.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> lista(String clave) =>
        (json[clave] as List? ?? []).cast<Map<String, dynamic>>();

    return ArchivoSincronizacion(
      formato: json['formato'] as int? ?? 1,
      movimientos: lista('movimientos'),
      facturas: lista('facturas'),
    );
  }

  Map<String, dynamic> toJson() => {
    'app': 'finza',
    'formato': formato,
    'actualizadoEn': DateTime.now().toIso8601String(),
    'movimientos': movimientos,
    'facturas': facturas,
  };
}
