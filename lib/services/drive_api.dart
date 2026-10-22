import 'dart:convert';

import 'package:http/http.dart' as http;

class DriveException implements Exception {
  DriveException(this.codigo, this.mensaje);

  final int codigo;
  final String mensaje;

  bool get noAutorizado => codigo == 401;

  @override
  String toString() => 'Drive respondió $codigo: $mensaje';
}

/// Cliente mínimo de la API REST de Google Drive v3 para un solo archivo.
///
/// Con el permiso `drive.file`, la app solo ve los archivos que ella misma
/// creó, así que buscar por nombre nunca devuelve archivos del usuario.
class DriveApi {
  DriveApi(this._accessToken, {http.Client? cliente})
    : _cliente = cliente ?? http.Client();

  final String _accessToken;
  final http.Client _cliente;

  static const _timeout = Duration(seconds: 30);

  Map<String, String> get _headers => {'Authorization': 'Bearer $_accessToken'};

  /// Id del archivo **más antiguo** con ese nombre, o null si no existe.
  /// Si dos celulares crearon uno a la vez, así los dos eligen el mismo.
  Future<String?> buscarArchivo(String nombre) async {
    final uri = Uri.https('www.googleapis.com', '/drive/v3/files', {
      'q': "name = '$nombre' and trashed = false",
      'spaces': 'drive',
      'fields': 'files(id)',
      'orderBy': 'createdTime',
      'pageSize': '1',
    });

    final respuesta = await _cliente
        .get(uri, headers: _headers)
        .timeout(_timeout);
    _verificar(respuesta);

    final archivos = (jsonDecode(respuesta.body)['files'] as List);
    return archivos.isEmpty ? null : archivos.first['id'] as String;
  }

  /// Contenido del archivo, o null si ya no existe (o se perdió el acceso).
  Future<String?> descargar(String id) async {
    final uri = Uri.https('www.googleapis.com', '/drive/v3/files/$id', {
      'alt': 'media',
    });

    final respuesta = await _cliente
        .get(uri, headers: _headers)
        .timeout(_timeout);
    if (respuesta.statusCode == 404) return null;
    _verificar(respuesta);

    return utf8.decode(respuesta.bodyBytes);
  }

  /// Crea el archivo y devuelve su id.
  Future<String> crear(String nombre, String contenido) async {
    const limite = 'finza_limite_multipart';
    final uri = Uri.https('www.googleapis.com', '/upload/drive/v3/files', {
      'uploadType': 'multipart',
      'fields': 'id',
    });

    final cuerpo = [
      '--$limite',
      'Content-Type: application/json; charset=UTF-8',
      '',
      jsonEncode({'name': nombre, 'mimeType': 'application/json'}),
      '--$limite',
      'Content-Type: application/json; charset=UTF-8',
      '',
      contenido,
      '--$limite--',
      '',
    ].join('\r\n');

    final respuesta = await _cliente
        .post(
          uri,
          headers: {
            ..._headers,
            'Content-Type': 'multipart/related; boundary=$limite',
          },
          body: utf8.encode(cuerpo),
        )
        .timeout(_timeout);
    _verificar(respuesta);

    return jsonDecode(respuesta.body)['id'] as String;
  }

  /// Reemplaza el contenido. Devuelve false si el archivo ya no existe.
  Future<bool> actualizar(String id, String contenido) async {
    final uri = Uri.https('www.googleapis.com', '/upload/drive/v3/files/$id', {
      'uploadType': 'media',
    });

    final respuesta = await _cliente
        .patch(
          uri,
          headers: {
            ..._headers,
            'Content-Type': 'application/json; charset=UTF-8',
          },
          body: utf8.encode(contenido),
        )
        .timeout(_timeout);
    if (respuesta.statusCode == 404) return false;
    _verificar(respuesta);

    return true;
  }

  /// Borra el archivo. No falla si ya no existe.
  Future<void> eliminar(String id) async {
    final uri = Uri.https('www.googleapis.com', '/drive/v3/files/$id');

    final respuesta = await _cliente
        .delete(uri, headers: _headers)
        .timeout(_timeout);
    if (respuesta.statusCode == 404) return;
    _verificar(respuesta);
  }

  void _verificar(http.Response respuesta) {
    if (respuesta.statusCode >= 200 && respuesta.statusCode < 300) return;

    var mensaje = respuesta.reasonPhrase ?? '';
    try {
      mensaje = jsonDecode(respuesta.body)['error']['message'] as String;
    } catch (_) {
      // El cuerpo no era el JSON de error de Google.
    }
    throw DriveException(respuesta.statusCode, mensaje);
  }
}
