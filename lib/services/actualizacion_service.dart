import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_info.dart';
import '../config/app_config.dart';
import '../models/actualizacion.dart';

class ActualizacionException implements Exception {
  ActualizacionException(this.mensaje);

  final String mensaje;

  @override
  String toString() => mensaje;
}

/// Busca versiones nuevas en el repo de GitHub, descarga el APK dentro de la
/// app y abre el instalador de Android.
///
/// Con token (repo privado) usa la API de GitHub; sin token, las URLs
/// públicas de raw.githubusercontent.com.
class ActualizacionService {
  ActualizacionService(this._prefs, {http.Client? cliente})
    : _cliente = cliente ?? http.Client();

  final SharedPreferences _prefs;
  final http.Client _cliente;

  static const _clavePospuesta = 'actualizacion_pospuesta';
  static const _esperaTrasPosponer = Duration(hours: 24);

  bool get _conToken => AppConfig.githubToken.isNotEmpty;

  Uri _urlArchivo(String ruta) {
    if (_conToken) {
      return Uri.https(
        'api.github.com',
        '/repos/${AppConfig.githubRepo}/contents/$ruta',
        {'ref': AppConfig.githubRama},
      );
    }
    return Uri.https(
      'raw.githubusercontent.com',
      '/${AppConfig.githubRepo}/${AppConfig.githubRama}/$ruta',
    );
  }

  Map<String, String> get _headers => _conToken
      ? {
          'Authorization': 'Bearer ${AppConfig.githubToken}',
          'Accept': 'application/vnd.github.raw+json',
          'X-GitHub-Api-Version': '2022-11-28',
        }
      : const {};

  /// Devuelve la actualización disponible o null si ya está al día.
  ///
  /// Con [manual] en false (al abrir la app), no vuelve a mostrar una versión
  /// que el usuario pospuso hace menos de 24 horas.
  Future<Actualizacion?> buscar({bool manual = false}) async {
    final respuesta = await _cliente
        .get(_urlArchivo('releases/latest.json'), headers: _headers)
        .timeout(const Duration(seconds: 10));

    // 404 = todavía no se publicó ninguna versión.
    if (respuesta.statusCode == 404) return null;
    if (respuesta.statusCode == 401 || respuesta.statusCode == 403) {
      throw ActualizacionException(
        'GitHub rechazó la consulta (${respuesta.statusCode}). '
        'Revisa el token de FINZA_GITHUB_TOKEN.',
      );
    }
    if (respuesta.statusCode != 200) {
      throw ActualizacionException('GitHub respondió ${respuesta.statusCode}.');
    }

    final actualizacion = Actualizacion.fromMap(
      jsonDecode(utf8.decode(respuesta.bodyBytes)) as Map<String, dynamic>,
    );

    final buildActual = int.tryParse(AppInfo.buildNumber) ?? 0;
    if (actualizacion.versionCode <= buildActual) return null;

    if (!manual && _pospuestaRecientemente(actualizacion)) return null;

    return actualizacion;
  }

  void posponer(Actualizacion actualizacion) {
    _prefs.setString(
      _clavePospuesta,
      '${actualizacion.versionCode}|${DateTime.now().toIso8601String()}',
    );
  }

  bool _pospuestaRecientemente(Actualizacion actualizacion) {
    final guardado = _prefs.getString(_clavePospuesta)?.split('|');
    if (guardado == null || guardado.length != 2) return false;
    if (guardado[0] != '${actualizacion.versionCode}') return false;

    final cuando = DateTime.tryParse(guardado[1]);
    return cuando != null &&
        DateTime.now().difference(cuando) < _esperaTrasPosponer;
  }

  /// Descarga el APK y devuelve la ruta del archivo. [progreso] recibe un
  /// valor entre 0 y 1 (o null si no se conoce el tamaño). Si [cancelada]
  /// devuelve true, la descarga se detiene y se borra lo descargado.
  Future<String> descargar(
    Actualizacion actualizacion, {
    void Function(double? progreso, int bytes)? progreso,
    bool Function()? cancelada,
  }) async {
    final solicitud = http.Request('GET', _urlArchivo(actualizacion.apk))
      ..headers.addAll(_headers);
    final respuesta = await _cliente
        .send(solicitud)
        .timeout(const Duration(seconds: 30));

    if (respuesta.statusCode != 200) {
      throw ActualizacionException(
        'No se pudo descargar el APK (${respuesta.statusCode}).',
      );
    }

    final total = respuesta.contentLength ?? actualizacion.tamano;
    final carpeta = await getTemporaryDirectory();
    await _borrarDescargasAnteriores(carpeta);

    // Nombre único: si se cancela y se reintenta, la descarga vieja no
    // pisa ni borra la nueva.
    final archivo = File(
      '${carpeta.path}/finza-${actualizacion.versionCode}-'
      '${DateTime.now().millisecondsSinceEpoch}.apk',
    );
    final salida = archivo.openWrite();
    var recibidos = 0;
    var completa = false;

    try {
      // Si la conexión se queda colgada, no se espera para siempre.
      await for (final bloque in respuesta.stream.timeout(
        const Duration(seconds: 30),
      )) {
        if (cancelada?.call() ?? false) {
          throw ActualizacionException('Descarga cancelada.');
        }
        salida.add(bloque);
        recibidos += bloque.length;
        progreso?.call(
          total == null || total == 0 ? null : recibidos / total,
          recibidos,
        );
      }
      completa = true;
    } on TimeoutException {
      throw ActualizacionException(
        'La descarga se detuvo. Revisa tu conexión e intenta de nuevo.',
      );
    } finally {
      await salida.close();
      if (!completa && await archivo.exists()) await archivo.delete();
    }

    final esperado = actualizacion.sha256;
    if (esperado != null) {
      final obtenido = (await sha256.bind(archivo.openRead()).first).toString();
      if (obtenido != esperado.toLowerCase()) {
        await archivo.delete();
        throw ActualizacionException(
          'El APK descargado está incompleto o dañado. Intenta de nuevo.',
        );
      }
    }

    return archivo.path;
  }

  /// Los APK de actualizaciones anteriores ya no sirven y pesan 15-20 MB.
  Future<void> _borrarDescargasAnteriores(Directory carpeta) async {
    try {
      await for (final archivo in carpeta.list()) {
        final nombre = archivo.uri.pathSegments.last;
        if (archivo is File &&
            nombre.startsWith('finza-') &&
            nombre.endsWith('.apk') &&
            DateTime.now().difference(await archivo.lastModified()) >
                const Duration(minutes: 10)) {
          await archivo.delete();
        }
      }
    } catch (_) {
      // Limpiar es opcional: si falla, se sigue con la descarga.
    }
  }

  /// Abre el instalador de Android con el APK descargado. La primera vez,
  /// Android pide permitir "instalar apps desconocidas" para Finza.
  Future<void> instalar(String rutaApk) async {
    final resultado = await OpenFilex.open(
      rutaApk,
      type: 'application/vnd.android.package-archive',
    );
    if (resultado.type != ResultType.done) {
      throw ActualizacionException(
        'No se pudo abrir el instalador: ${resultado.message}',
      );
    }
  }
}
