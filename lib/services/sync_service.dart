import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../database/database_helper.dart';
import '../models/factura.dart';
import '../models/movimiento.dart';
import '../providers/finanzas_provider.dart';
import 'drive_api.dart';
import 'sincronizacion.dart';

enum EstadoSync {
  /// Falta el Client ID de Google al compilar (ver AppConfig).
  noConfigurado,

  /// No hay cuenta de Google conectada.
  desconectado,

  /// Hay cuenta, pero falta (o se revocó) el permiso de Drive, o hay que
  /// volver a elegir la cuenta.
  sinPermiso,
  listo,
  sincronizando,

  /// Sin internet o Drive no responde. Los datos siguen guardados en el
  /// teléfono y se sincronizan solos cuando vuelva el servicio.
  sinConexion,

  /// Error que no se arregla solo reintentando (ver [SyncService.error]).
  error,
}

/// Sincroniza los datos con un archivo en el Drive del usuario, sin backend.
///
/// El teléfono es la fuente principal: la app funciona igual sin internet y
/// Drive es la copia. Si Drive no está disponible, los cambios quedan
/// marcados como pendientes (aunque se cierre la app) y se suben solos
/// cuando vuelve la conexión, al volver a abrir la app o en el siguiente
/// reintento.
///
/// Usa el permiso `drive.file`: la app solo puede ver y modificar los
/// archivos que ella misma creó (acá, `finza_datos.json`), nada más del
/// Drive del usuario.
class SyncService extends ChangeNotifier with WidgetsBindingObserver {
  SyncService(
    this._finanzas,
    this._prefs, {
    DatabaseHelper? db,
    this._clienteHttp,
    Stream<List<ConnectivityResult>>? conectividad,
    Future<bool> Function()? hayRed,
  }) : _db = db ?? DatabaseHelper.instance,
       _hayRedPersonalizado = hayRed {
    ultimaSincronizacion = _leerFecha(_claveUltima);
    if (conectividad != null) _escucharConectividad(conectividad);
    if (vinculado && AppConfig.syncConfigurado) estado = EstadoSync.listo;
  }

  static const nombreArchivo = 'finza_datos.json';
  static const _scopes = ['https://www.googleapis.com/auth/drive.file'];
  static const _claveArchivoId = 'drive_archivo_id';
  static const _claveUltima = 'drive_ultima_sincronizacion';
  static const _claveUltimoCambio = 'drive_ultimo_cambio_local';
  static const _claveCuenta = 'drive_cuenta';

  /// Espera entre reintentos tras una falla temporal. Después del último,
  /// se sigue reintentando con esa misma espera.
  static const esperasReintento = [
    Duration(seconds: 15),
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 2),
    Duration(minutes: 5),
    Duration(minutes: 10),
  ];

  final FinanzasProvider _finanzas;
  final SharedPreferences _prefs;
  final DatabaseHelper _db;
  final http.Client? _clienteHttp;
  final Future<bool> Function()? _hayRedPersonalizado;
  final _googleSignIn = GoogleSignIn.instance;

  EstadoSync estado = AppConfig.syncConfigurado
      ? EstadoSync.desconectado
      : EstadoSync.noConfigurado;
  GoogleSignInAccount? cuenta;
  DateTime? ultimaSincronizacion;
  String? error;

  /// Cuándo se va a reintentar, si la última sincronización falló por un
  /// problema temporal.
  DateTime? proximoReintento;

  Future<void>? _init;
  bool _observando = false;
  bool _intentoSilencioso = false;
  bool _repetirAlTerminar = false;
  int _intentosFallidos = 0;

  /// Sube al desconectar: una sincronización que ya estaba en curso no
  /// vuelve a escribir el estado ni el id del archivo.
  int _generacion = 0;
  Timer? _temporizador;
  Timer? _reintento;
  Future<void>? _enCurso;
  StreamSubscription<List<ConnectivityResult>>? _suscripcionRed;
  Future<String?> Function()? _tokenDePrueba;

  /// El usuario conectó Drive y no lo desconectó. Se guarda en el teléfono
  /// para no "olvidar" la cuenta si al abrir la app no hay internet.
  bool get vinculado => _prefs.getString(_claveCuenta) != null;

  String? get email => cuenta?.email ?? _prefs.getString(_claveCuenta);

  /// Hay cambios hechos en el teléfono que todavía no llegaron a Drive.
  bool get hayCambiosPendientes {
    final ultimoCambio = _leerFecha(_claveUltimoCambio);
    if (ultimoCambio == null) return false;
    return ultimaSincronizacion == null ||
        ultimoCambio.isAfter(ultimaSincronizacion!);
  }

  /// Las fechas se guardan en UTC y se muestran en hora local.
  DateTime? _leerFecha(String clave) {
    final valor = _prefs.getString(clave);
    return valor == null ? null : DateTime.tryParse(valor)?.toLocal();
  }

  Future<void> _guardarFecha(String clave, DateTime fecha) =>
      _prefs.setString(clave, fecha.toUtc().toIso8601String());

  /// Inicia Google y, si había una cuenta vinculada, sincroniza. Se puede
  /// llamar varias veces: espera a la misma inicialización y, si falló,
  /// la vuelve a intentar.
  Future<void> inicializar() async {
    if (!AppConfig.syncConfigurado) return;

    if (!_observando) {
      _observando = true;
      WidgetsBinding.instance.addObserver(this);
      _suscripcionRed ??= _escucharConectividad(
        Connectivity().onConnectivityChanged,
      );
    }

    final primeraVez = _init == null;
    _init ??= _googleSignIn.initialize(
      serverClientId: AppConfig.googleServerClientId,
    );
    try {
      await _init;
    } catch (e) {
      _init = null;
      _falloDeCuenta('No se pudo iniciar Google: $e');
      return;
    }

    if (primeraVez && vinculado) await sincronizar();
  }

  /// Conecta una cuenta de Google y pide el permiso de Drive. Debe llamarse
  /// desde un botón (muestra la interfaz de Google).
  Future<void> conectar() async {
    if (!AppConfig.syncConfigurado) return;
    await inicializar();
    if (_init == null) return; // Falló la inicialización (ya se informó).

    try {
      cuenta = await _googleSignIn.authenticate(scopeHint: _scopes);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        error = null;
        estado = vinculado ? EstadoSync.sinPermiso : EstadoSync.desconectado;
        notifyListeners();
      } else {
        _falloDeCuenta(
          'No se pudo iniciar sesión con Google: '
          '${e.description ?? e.code.name}',
        );
      }
      return;
    } catch (e) {
      _falloDeCuenta('No se pudo iniciar sesión con Google: $e');
      return;
    }

    try {
      await cuenta!.authorizationClient.authorizeScopes(_scopes);
    } catch (_) {
      // Al cancelar la pantalla de permiso, Android no lo informa como
      // "cancelado": cualquier falla acá significa que no hay permiso.
      _falloDeCuenta('Falta el permiso para guardar en tu Drive.');
      return;
    }

    _intentoSilencioso = true;
    await _prefs.setString(_claveCuenta, cuenta!.email);
    error = null;
    await sincronizar();
  }

  /// Cierra la sesión. Los datos del teléfono y el archivo de Drive quedan
  /// como están.
  Future<void> desconectar() async {
    _generacion++;
    _temporizador?.cancel();
    _cancelarReintento();
    try {
      await _googleSignIn.disconnect();
    } catch (_) {
      // Si falla la revocación (por ejemplo, sin internet), igual se olvida
      // la cuenta en el teléfono.
    }
    cuenta = null;
    error = null;
    estado = AppConfig.syncConfigurado
        ? EstadoSync.desconectado
        : EstadoSync.noConfigurado;
    await _prefs.remove(_claveArchivoId);
    await _prefs.remove(_claveCuenta);
    notifyListeners();
  }

  /// Se llama después de cada cambio local. Lo marca como pendiente (queda
  /// guardado aunque se cierre la app) y agenda la subida unos segundos
  /// después, para no subir el archivo en cada tecla.
  void programarSincronizacion() {
    _guardarFecha(_claveUltimoCambio, DateTime.now());
    if (!vinculado) return;

    notifyListeners();
    _temporizador?.cancel();
    _temporizador = Timer(const Duration(seconds: 3), sincronizar);
  }

  /// Baja el archivo de Drive, lo combina con los datos locales y sube el
  /// resultado si hay algo nuevo acá. Si ya hay una en curso, se repite al
  /// terminar.
  Future<void> sincronizar() async {
    if (!vinculado) return;

    if (_enCurso != null) {
      _repetirAlTerminar = true;
      return _enCurso;
    }

    _temporizador?.cancel();
    _cancelarReintento();
    _enCurso = _sincronizarConReintento();
    try {
      await _enCurso;
    } finally {
      _enCurso = null;
    }

    if (_repetirAlTerminar) {
      _repetirAlTerminar = false;
      await sincronizar();
    }
  }

  Future<void> _sincronizarConReintento() async {
    final generacion = _generacion;
    bool vigente() => generacion == _generacion;

    final inicio = DateTime.now();
    estado = EstadoSync.sincronizando;
    error = null;
    notifyListeners();

    try {
      if (!await _hayRed()) throw const SocketException('Sin conexión');

      final token = await _tokenDeAcceso();
      if (!vigente()) return;
      if (token == null) {
        estado = EstadoSync.sinPermiso;
        notifyListeners();
        return;
      }

      try {
        await sincronizarCon(_drive(token), generacion: generacion);
      } on DriveException catch (e) {
        if (!e.noAutorizado || cuenta == null) rethrow;
        // Token vencido: se descarta y se intenta una vez con uno nuevo.
        await cuenta!.authorizationClient.clearAuthorizationToken(
          accessToken: token,
        );
        final nuevo = await _tokenDeAcceso();
        if (!vigente()) return;
        if (nuevo == null) {
          estado = EstadoSync.sinPermiso;
          notifyListeners();
          return;
        }
        await sincronizarCon(_drive(nuevo), generacion: generacion);
      }
      if (!vigente()) return;

      // Se guarda la hora de inicio: un cambio hecho mientras se subía el
      // archivo queda después y sigue contando como pendiente.
      ultimaSincronizacion = inicio;
      await _guardarFecha(_claveUltima, inicio);
      _intentosFallidos = 0;
      estado = EstadoSync.listo;
      notifyListeners();
    } catch (e) {
      if (!vigente()) return;
      if (esFallaTemporal(e)) {
        _sinConexion(e);
      } else if (e is GoogleSignInException) {
        // Por ejemplo, se quitó la cuenta del teléfono o se revocó el
        // permiso: hay que volver a conectar, reintentar no sirve.
        error = e.description ?? e.code.name;
        estado = EstadoSync.sinPermiso;
        notifyListeners();
      } else {
        _fallo(e is DriveException ? e.mensaje : '$e');
      }
    }
  }

  DriveApi _drive(String token) => DriveApi(token, cliente: _clienteHttp);

  Future<bool> _hayRed() async {
    if (_hayRedPersonalizado != null) return _hayRedPersonalizado();
    try {
      final resultado = await Connectivity().checkConnectivity();
      return !resultado.every((r) => r == ConnectivityResult.none);
    } catch (_) {
      return true; // Si no se puede saber, se intenta igual.
    }
  }

  bool get _enPrimerPlano {
    final estadoApp = WidgetsBinding.instance.lifecycleState;
    return estadoApp == null || estadoApp == AppLifecycleState.resumed;
  }

  /// Token de Drive sin mostrar interfaz, o null si hace falta que el
  /// usuario vuelva a dar permiso.
  Future<String?> _tokenDeAcceso() async {
    if (_tokenDePrueba != null) return _tokenDePrueba!();

    if (cuenta == null) {
      // En Android, el intento "silencioso" puede terminar mostrando un
      // selector de cuentas. Se hace una sola vez por sesión, con la app
      // abierta y con internet; si no alcanza, se espera a que el usuario
      // toque "Dar permiso".
      if (_intentoSilencioso) return null;
      if (!_enPrimerPlano) {
        throw const SocketException('Se recupera la sesión al abrir la app');
      }
      _intentoSilencioso = true;
      cuenta = await _googleSignIn.attemptLightweightAuthentication();
      if (cuenta == null) return null;
    }

    final autorizacion = await cuenta!.authorizationClient
        .authorizationForScopes(_scopes);
    return autorizacion?.accessToken;
  }

  /// Fallas que se arreglan solas: sin internet, Drive caído o saturado.
  /// Los errores de Google (cuenta, permiso, configuración) no entran: antes
  /// de pedir el token ya se verificó que hay red.
  @visibleForTesting
  static bool esFallaTemporal(Object e) {
    if (e is SocketException ||
        e is TimeoutException ||
        e is HandshakeException ||
        e is http.ClientException) {
      return true;
    }
    if (e is DriveException) {
      return e.codigo == 408 || e.codigo == 429 || e.codigo >= 500;
    }
    return false;
  }

  void _sinConexion(Object causa) {
    debugPrint('Sincronización: sin conexión ($causa)');
    final espera =
        esperasReintento[_intentosFallidos.clamp(
          0,
          esperasReintento.length - 1,
        )];
    _intentosFallidos++;

    estado = EstadoSync.sinConexion;
    error = null;
    proximoReintento = DateTime.now().add(espera);
    _reintento = Timer(espera, sincronizar);
    notifyListeners();
  }

  void _cancelarReintento() {
    _reintento?.cancel();
    _reintento = null;
    proximoReintento = null;
  }

  StreamSubscription<List<ConnectivityResult>> _escucharConectividad(
    Stream<List<ConnectivityResult>> cambios,
  ) {
    return _suscripcionRed = cambios.listen((resultado) {
      final hayRed = !resultado.every((r) => r == ConnectivityResult.none);
      // Volvió la red: no se espera al próximo reintento.
      if (hayRed &&
          vinculado &&
          (estado == EstadoSync.sinConexion || hayCambiosPendientes)) {
        _intentosFallidos = 0;
        sincronizar();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!vinculado) return;

    if (state == AppLifecycleState.resumed) {
      final hace = ultimaSincronizacion == null
          ? null
          : DateTime.now().difference(ultimaSincronizacion!);
      if (hayCambiosPendientes ||
          estado == EstadoSync.sinConexion ||
          estado == EstadoSync.error ||
          hace == null ||
          hace > const Duration(minutes: 5)) {
        _intentosFallidos = 0;
        sincronizar();
      }
    } else if (state == AppLifecycleState.paused &&
        hayCambiosPendientes &&
        cuenta != null) {
      // Al salir de la app no se esperan los 3 segundos: se sube ya.
      sincronizar();
    }
  }

  /// Simula una cuenta conectada para los tests (sin Google).
  @visibleForTesting
  Future<void> conectarParaPruebas(Future<String?> Function() token) async {
    _tokenDePrueba = token;
    await _prefs.setString(_claveCuenta, 'prueba@finza.app');
  }

  /// Un ciclo de sincronización con [drive]. Público solo para los tests.
  ///
  /// Si se desconectó la cuenta mientras corría ([generacion] distinta), no
  /// guarda el id del archivo.
  @visibleForTesting
  Future<void> sincronizarCon(
    DriveApi drive, {
    int? generacion,
    bool adoptoArchivo = false,
  }) async {
    var archivoId = _prefs.getString(_claveArchivoId);
    String? contenido;

    if (archivoId != null) {
      contenido = await drive.descargar(archivoId);
      if (contenido == null) archivoId = null; // Se borró en Drive.
    }
    if (archivoId == null) {
      archivoId = await drive.buscarArchivo(nombreArchivo);
      if (archivoId != null) contenido = await drive.descargar(archivoId);
    }

    final remoto = contenido == null
        ? ArchivoSincronizacion(movimientos: [], facturas: [])
        : ArchivoSincronizacion.fromJson(
            jsonDecode(contenido) as Map<String, dynamic>,
          );

    if (remoto.esDeUnaVersionMasNueva) {
      throw Exception(
        'Los datos de Drive son de una versión más nueva de Finza. '
        'Actualiza la app para sincronizar.',
      );
    }

    final local = await _db.exportarParaSincronizar();
    final movimientos = combinarRegistros(
      local['movimientos']!,
      remoto.movimientos,
    );
    final facturas = combinarRegistros(local['facturas']!, remoto.facturas);

    if (movimientos.paraAplicarLocal.isNotEmpty ||
        facturas.paraAplicarLocal.isNotEmpty) {
      await _db.aplicarCambiosRemotos(
        movimientos: movimientos.paraAplicarLocal
            .map(Movimiento.fromJson)
            .toList(),
        facturas: facturas.paraAplicarLocal.map(Factura.fromJson).toList(),
      );
      await _finanzas.cargar();
    }

    var creado = false;
    if (archivoId == null || movimientos.hayQueSubir || facturas.hayQueSubir) {
      final nuevoContenido = jsonEncode(
        ArchivoSincronizacion(
          movimientos: movimientos.combinados,
          facturas: facturas.combinados,
        ).toJson(),
      );

      if (archivoId == null ||
          !await drive.actualizar(archivoId, nuevoContenido)) {
        archivoId = await drive.crear(nombreArchivo, nuevoContenido);
        creado = true;
      }
    }

    if (generacion != null && generacion != _generacion) return;

    // Si otro celular creó su archivo al mismo tiempo, los dos se quedan con
    // el más antiguo: se borra el recién creado (sus datos siguen en este
    // teléfono) y se combina de nuevo con el que queda.
    if (creado && !adoptoArchivo) {
      final masAntiguo = await drive.buscarArchivo(nombreArchivo);
      if (masAntiguo != null && masAntiguo != archivoId) {
        await drive.eliminar(archivoId);
        await _prefs.setString(_claveArchivoId, masAntiguo);
        return sincronizarCon(
          drive,
          generacion: generacion,
          adoptoArchivo: true,
        );
      }
    }

    await _prefs.setString(_claveArchivoId, archivoId);
  }

  /// Error al conectar la cuenta (no de sincronización): si no había cuenta
  /// vinculada, se vuelve a "Conectar con Google" mostrando el motivo.
  void _falloDeCuenta(String mensaje) {
    debugPrint('Sincronización: $mensaje');
    error = mensaje;
    estado = vinculado ? EstadoSync.sinPermiso : EstadoSync.desconectado;
    notifyListeners();
  }

  void _fallo(String mensaje) {
    debugPrint('Sincronización: $mensaje');
    error = mensaje;
    estado = EstadoSync.error;
    notifyListeners();
  }

  @override
  void dispose() {
    _temporizador?.cancel();
    _reintento?.cancel();
    _suscripcionRed?.cancel();
    if (_observando) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
