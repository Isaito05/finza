import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:finza/app_info.dart';
import 'package:finza/services/actualizacion_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RutasFalsas extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _RutasFalsas(this.carpeta);

  final String carpeta;

  @override
  Future<String?> getTemporaryPath() async => carpeta;
}

void main() {
  late Directory carpeta;
  final apk = List<int>.generate(50000, (i) => i % 251);

  setUp(() async {
    carpeta = await Directory.systemTemp.createTemp('finza_update');
    PathProviderPlatform.instance = _RutasFalsas(carpeta.path);
    SharedPreferences.setMockInitialValues({});
    AppInfo.buildNumber = '2';
  });

  tearDown(() => carpeta.delete(recursive: true));

  Future<ActualizacionService> servicio({
    int versionCode = 3,
    String? sha,
    List<int>? contenidoApk,
  }) async {
    final cliente = MockClient((solicitud) async {
      if (solicitud.url.path.endsWith('latest.json')) {
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'version': '1.2.0',
              'versionCode': versionCode,
              'apk': 'releases/Finza-v1.2.0-$versionCode.apk',
              'sha256': sha ?? sha256.convert(apk).toString(),
              'tamano': apk.length,
              'changelog': 'Sincronización con Drive',
            }),
          ),
          200,
        );
      }
      return http.Response.bytes(contenidoApk ?? apk, 200);
    });
    return ActualizacionService(
      await SharedPreferences.getInstance(),
      cliente: cliente,
    );
  }

  test('encuentra una versión nueva y no una igual a la instalada', () async {
    expect(
      (await (await servicio()).buscar())?.cambios,
      'Sincronización con Drive',
    );
    expect(await (await servicio(versionCode: 2)).buscar(), isNull);
  });

  test('al posponer no insiste al abrir, pero sí al buscar a mano', () async {
    final actualizaciones = await servicio();
    final encontrada = (await actualizaciones.buscar())!;
    actualizaciones.posponer(encontrada);

    expect(await actualizaciones.buscar(), isNull);
    expect(await actualizaciones.buscar(manual: true), isNotNull);
  });

  test('descarga el APK, informa el progreso y verifica el SHA-256', () async {
    final actualizaciones = await servicio();
    final encontrada = (await actualizaciones.buscar())!;
    final progresos = <double?>[];

    final ruta = await actualizaciones.descargar(
      encontrada,
      progreso: (p, _) => progresos.add(p),
    );

    expect(await File(ruta).readAsBytes(), apk);
    expect(progresos.last, 1.0);
  });

  test('cancelar detiene la descarga y borra lo descargado', () async {
    final actualizaciones = await servicio();
    final encontrada = (await actualizaciones.buscar())!;

    await expectLater(
      actualizaciones.descargar(encontrada, cancelada: () => true),
      throwsA(isA<ActualizacionException>()),
    );
    expect(carpeta.listSync(), isEmpty);
  });

  test('rechaza un APK dañado', () async {
    final actualizaciones = await servicio(contenidoApk: apk.sublist(0, 1000));
    final encontrada = (await actualizaciones.buscar())!;

    await expectLater(
      actualizaciones.descargar(encontrada),
      throwsA(isA<ActualizacionException>()),
    );
    expect(carpeta.listSync(), isEmpty);
  });
}
