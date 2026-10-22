/// Configuración que se inyecta al compilar con
/// `--dart-define-from-file=finza_config.json` (ver finza_config.example.json).
/// No se commitea: el token de GitHub es privado.
class AppConfig {
  AppConfig._();

  /// Client ID **Web** de Google Cloud (termina en
  /// `.apps.googleusercontent.com`). En Android, google_sign_in lo exige como
  /// `serverClientId`. Vacío = la sincronización con Drive queda desactivada.
  static const String googleServerClientId = String.fromEnvironment(
    'FINZA_GOOGLE_CLIENT_ID',
  );

  /// Token de GitHub de solo lectura para bajar actualizaciones desde el repo
  /// privado. Vacío = se intenta por la URL pública (solo sirve si el repo es
  /// público).
  static const String githubToken = String.fromEnvironment(
    'FINZA_GITHUB_TOKEN',
  );

  static const String githubRepo = 'Isaito05/finza';
  static const String githubRama = 'master';

  static bool get syncConfigurado => googleServerClientId.isNotEmpty;
}
