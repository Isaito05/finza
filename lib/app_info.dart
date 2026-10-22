import 'package:package_info_plus/package_info_plus.dart';

class AppInfo {
  AppInfo._();

  static String version = '';
  static String buildNumber = '';

  static String get versionLabel =>
      buildNumber.isEmpty ? 'v$version' : 'v$version+$buildNumber';

  static Future<void> cargar() async {
    final info = await PackageInfo.fromPlatform();
    version = info.version;
    buildNumber = info.buildNumber;
  }
}
