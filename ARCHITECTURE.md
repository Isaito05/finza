# Finza: arquitectura

Referencia para entender cómo está armada la app y dónde va cada cambio, sin
releer todo el código. Para configurar, compilar y publicar, ver el
[`README.md`](README.md). El formato de este documento viene del
`ARCHITECTURE.md` de top-list.

## Stack

| Capa | Tecnología |
|---|---|
| App | Flutter (Dart `^3.13.4`), solo Android |
| Estado | `provider`: `FinanzasProvider`, `PreferenciasProvider` y `SyncService` (ChangeNotifier); `RecordatoriosService` y `ActualizacionService` (Provider plano) |
| Datos locales | SQLite (`sqflite`), base `finza.db` versión 3 |
| Preferencias | `shared_preferences` (tema, filtros, recordatorios, estado de la sincronización) |
| Sincronización | Google Drive REST v3 con `http`; login con `google_sign_in` 7 y permiso `drive.file`; `connectivity_plus` para reintentar cuando vuelve la red |
| Recordatorios | `flutter_local_notifications` + `timezone` / `flutter_timezone` |
| Actualizaciones | API de GitHub (repo privado, token de solo lectura), `crypto` (SHA-256), `open_filex` (instalador) |
| Configuración | `--dart-define-from-file=finza_config.json` → `lib/config/app_config.dart` |

## Flujo de datos

```
Pantallas ──watch──▶ FinanzasProvider ──▶ DatabaseHelper (SQLite)
    │                     │
    └── acciones.dart ────┘ guardar / eliminar / pagar
                          │
                          ├─ alModificarLocalmente ─▶ SyncService.programarSincronizacion (3 s después)
                          └─ notifyListeners ───────▶ RecordatoriosService.programar
```

- **Toda escritura pasa por `FinanzasProvider`**, que recarga desde la base y
  notifica. Por eso las pestañas nunca quedan desactualizadas: no hay que
  acordarse de recargar después de guardar.
- **Las acciones de la interfaz** que se repiten (abrir formularios, eliminar
  con "Deshacer", cambiar el estado de una factura, el menú de opciones)
  están en `widgets/acciones.dart`. Una pantalla nueva reutiliza esas en vez
  de copiarlas.
- **Colores con significado** (ingreso, gasto, alerta): `ColoresFinza.de(context)`,
  nunca `Colors.green` o `Colors.red` directo, para que funcionen en modo oscuro.

## Navegación

`screens/home_shell.dart` arma la barra superior (indicador de Drive y
Ajustes), un `NavigationBar` con 4 pestañas en un `IndexedStack` (conserva el
scroll y la búsqueda) y el botón flotante según la pestaña.

| # | Pestaña | Pantalla | Botón flotante |
|---|---|---|---|
| 0 | Inicio | `InicioScreen` | Agregar movimiento |
| 1 | Movimientos | `MovimientosScreen` | Agregar movimiento |
| 2 | Estadísticas | `EstadisticasScreen` | — |
| 3 | Facturas | `FacturasScreen` | Agregar factura |

`HomeShell.tabIndex` es un `ValueNotifier<int>` estático (igual que en
top-list): el banner de facturas, la tarjeta de Inicio y las notificaciones
saltan a Facturas sin pasar por el `Navigator`.

Desde Ajustes se llega a la `PapeleraScreen`. Los formularios
(`MovimientoFormScreen`, `FacturaFormScreen`) sirven para crear y editar:
sin parámetro crean y con el modelo editan.

## Modelo de datos

Ambas tablas (`movimientos`, `facturas`) tienen, además de sus campos:

| Campo | Para qué |
|---|---|
| `id` | Clave local de SQLite. **No** viaja a Drive. |
| `uuid` | Identidad estable entre celulares. La sincronización compara por este campo. |
| `actualizadoEn` | Se actualiza en **cada** cambio. En la sincronización gana el más reciente. Se guarda en **UTC** (`toUtc()` en `toJson`) para comparar bien entre celulares con distinta zona horaria. |
| `eliminadoEn` | No nulo = está en la papelera. |
| `purgado` | Eliminado definitivamente. La fila se conserva para que el borrado llegue a los otros celulares. |

Reglas:
- **Nunca se borra una fila con `DELETE`.** Eliminar es `eliminadoEn = ahora`;
  vaciar la papelera es `purgado = 1`. Un `DELETE` haría que el registro
  "reviva" desde Drive en la próxima sincronización.
- La papelera muestra lo eliminado en los últimos 30 días
  (`FinanzasProvider.diasEnPapelera`). Al cargar los datos, lo que pasó ese
  plazo se purga solo (`purgado = 1`, con su `actualizadoEn`), así la purga
  también llega a los otros celulares.
- Todo cambio de un registro debe pasar por `copyWith(actualizadoEn: ahora)`
  (ya lo hacen los métodos del provider). Si no, la sincronización no lo sube.
- `Factura.estado` solo guarda `Pendiente` o `Pagada`. *Vencida*, *Vence hoy*
  y *Próxima* se calculan con `estadoDeFactura()` según la fecha.
- **Recurrentes:** al marcar pagada una factura recurrente se crea la del
  siguiente periodo (`siguienteVencimiento()`, que ajusta el 31 al último día
  del mes). Su `uuid` se **deriva** de la factura pagada y la fecha (UUID
  v5): si se paga la misma factura en dos celulares antes de sincronizar,
  los dos crean el mismo registro y queda uno solo. Si ya existe (aunque
  esté eliminada), no se vuelve a crear.

Migraciones en `DatabaseHelper._onUpgrade`: v1→v2 crea `facturas` y v2→v3
agrega los campos de sincronización y asigna `uuid` a las filas existentes.
Para un cambio de esquema nuevo, sube `version` y agrega un bloque
`if (oldVersion < 4)`. Hay un test que migra una base v2 real
(`test/datos_test.dart`).

## Sincronización con Google Drive

Sin backend: el Drive del usuario es el "servidor".

- **Permiso `drive.file`:** Finza solo ve los archivos que creó. Guarda uno,
  `finza_datos.json`, con todos los registros (incluidos los purgados) en
  formato JSON (`toJson()` de cada modelo).
- **El teléfono es la fuente principal.** La app funciona igual sin
  internet; Drive es la copia. Nunca se espera a Drive para guardar.
- **Cuándo sincroniza:** al abrir la app (si hay cuenta vinculada), 3
  segundos después de cada cambio, al salir de la app si hay cambios sin
  subir, al volver a la app, cuando vuelve la red, al deslizar hacia abajo en
  cualquier pestaña y con "Sincronizar ahora". Si se pide una mientras otra
  está en curso, se repite al terminar.
- **Modo sin conexión (fallback):**
  - *Cambios pendientes:* cada cambio local guarda su hora en
    `shared_preferences` (`drive_ultimo_cambio_local`). Hay pendientes si esa
    hora es posterior al inicio de la última sincronización exitosa. Esto
    sobrevive aunque se cierre la app.
  - *Cuenta vinculada:* el correo se guarda en el teléfono
    (`drive_cuenta`). Si al abrir la app no hay internet y Google no puede
    recuperar la sesión, Finza no "olvida" la cuenta y lo reintenta después.
  - *Fallas temporales* (`SyncService.esFallaTemporal`): sin red, timeout,
    conexión cortada o Drive 408/429/5xx. Los errores de Google (cuenta o
    permiso) no cuentan, porque ya se verificó que hay red antes. El estado
    pasa a `sinConexion` (nube con flecha, color de alerta) y se reintenta
    solo con esperas crecientes: 15 s, 30 s, 1 min, 2 min, 5 min y luego
    cada 10 min. Si `connectivity_plus` avisa que volvió la red, se
    sincroniza en el momento, sin esperar el reintento.
  - *Errores permanentes* (permiso revocado, API deshabilitada, archivo de
    una versión más nueva): estado `error` o `sinPermiso`, sin reintento
    automático; se vuelve a intentar al abrir la app o tras un cambio.
- **Cómo combina** (`services/sincronizacion.dart`, función pura con tests):
  baja el archivo; por cada `uuid` gana el `actualizadoEn` más reciente; lo
  que ganó en Drive se escribe en SQLite; si algo ganó localmente, sube el
  archivo combinado. Así dos celulares que editan cosas distintas no se pisan.
  Al aplicar lo de Drive, `DatabaseHelper` vuelve a comparar `actualizadoEn`
  dentro de la transacción: si el usuario editó el registro mientras se
  descargaba el archivo, no se pisa.
  Si los dos editan **el mismo** registro, gana el último cambio (depende de
  que la hora de los celulares sea correcta).
- **Un solo archivo aunque dos celulares lo creen a la vez:** la búsqueda
  devuelve el archivo **más antiguo**. Si al crear el suyo un celular
  encuentra uno anterior, borra el que acaba de crear (sus datos siguen en
  el teléfono) y combina con el más antiguo.
- **Sesión de Google:** el intento silencioso de recuperar la cuenta
  (`attemptLightweightAuthentication`) se hace **una sola vez por sesión**,
  con la app abierta y con red: en Android puede terminar mostrando un
  selector de cuentas. Si no alcanza, el estado pasa a `sinPermiso` y se
  espera a que el usuario toque "Dar permiso". Cancelar la pantalla de
  permiso de Drive llega como error genérico; se trata como "sin permiso",
  no como falla de sincronización.
- **Desconectar a mitad de una sincronización:** un contador de
  generación evita que la sincronización en curso vuelva a guardar el
  estado o el id del archivo.
- **Formato versionado:** `formato: 1`. Si una versión futura cambia el
  formato, sube `formatoArchivo`; las versiones viejas se niegan a
  sobrescribir un archivo más nuevo y piden actualizar.
- **Token vencido (401):** se descarta, se pide otro sin interfaz y se
  reintenta una vez. Si hace falta interacción, el estado pasa a
  `sinPermiso` y Ajustes muestra "Dar permiso".
- `SyncService.sincronizarCon(DriveApi)` es público solo para los tests, que
  usan un Drive simulado con `MockClient`.

## Recordatorios

`RecordatoriosService` programa, para cada factura pendiente, un aviso a las
9:00 del día anterior y otro a las 9:00 del día del vencimiento (máximo 60).
Se reprograma cuando cambian las facturas o el ajuste. Si lo que hay que
avisar no cambió, no hace nada. Usa alarmas **inexactas**, que no necesitan
el permiso de alarmas exactas. Si la zona horaria del teléfono no está en la
base de `timezone`, usa UTC (los avisos igual salen a la hora correcta,
porque se programan con el instante exacto). El ícono es un vector
monocromo (`res/drawable/ic_stat_finza.xml`), protegido de R8 con
`res/raw/keep.xml`. El permiso de notificaciones (Android 13+) se
pide la primera vez que hay algo que avisar o al activar el ajuste. Tocar
la notificación abre la pestaña Facturas.

## Actualizaciones

`release.ps1` publica `releases/Finza-vX.Y.Z-N.apk`, `releases/finza.apk`
(link fijo) y `releases/latest.json` (`version`, `versionCode`, `apk`,
`sha256`, `tamano`, `changelog`). La app compara `versionCode` con su build
(`AppInfo.buildNumber`), descarga con progreso, verifica el SHA-256 y abre el
instalador. La descarga se corta si se queda 30 s sin datos, se puede
cancelar y usa un nombre de archivo único (las descargas viejas se borran).
El detalle está en el README.

## Pruebas

| Archivo | Qué cubre |
|---|---|
| `test/sincronizacion_test.dart` | Reglas de combinación (gana el más reciente, borrados, formato futuro) |
| `test/datos_test.dart` | Migración v2→v3 con SQLite real, provider (papelera, recurrentes), `SyncService` contra un Drive simulado, modo sin conexión (Drive caído, reintentos, recuperación al volver la red) y casos de borde (edición durante la sincronización, dos celulares a la vez, desconectar a mitad, purga) |
| `test/actualizacion_test.dart` | Buscar, posponer, descargar, cancelar y rechazar un APK dañado |
| `test/utilidades_test.dart` | Formato de dinero, lectura de montos, fechas, estados y filtros |
| `test/app_test.dart` | Interfaz: agregar un gasto, recorrer pestañas en modo oscuro, papelera |

## Pendientes conocidos

- **Metas de ahorro y presupuestos** (están en el título del proyecto): todavía no existen.
- **Estadísticas** suman todo el historial. Falta un selector de periodo (se puede reutilizar `FiltroMovimientos.rango()`).
- Pagar una factura no registra el gasto en Movimientos. Se podría ofrecer al marcarla pagada.
