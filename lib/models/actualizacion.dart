/// Contenido de `releases/latest.json` (lo escribe release.ps1).
class Actualizacion {
  final String version;
  final int versionCode;

  /// Ruta del APK dentro del repo, ej. `releases/Finza-v1.1.0-2.apk`.
  final String apk;

  /// Para verificar que la descarga llegó completa y sin alterar.
  final String? sha256;
  final int? tamano;
  final String? cambios;

  Actualizacion({
    required this.version,
    required this.versionCode,
    required this.apk,
    this.sha256,
    this.tamano,
    this.cambios,
  });

  String get etiqueta => 'v$version+$versionCode';

  factory Actualizacion.fromMap(Map<String, dynamic> map) {
    return Actualizacion(
      version: map['version'] as String,
      versionCode: map['versionCode'] as int,
      apk: map['apk'] as String,
      sha256: map['sha256'] as String?,
      tamano: map['tamano'] as int?,
      cambios: map['changelog'] as String?,
    );
  }
}
