# Finza --- Contexto del proyecto

## Descripción

**Nombre:** Finza\
**Lema:** "Controla tu dinero, alcanza tus metas."

**Título académico:** "Finza: Aplicación móvil para la gestión y control
de las finanzas personales mediante el seguimiento de ingresos, gastos,
facturas y metas de ahorro".

Finza es una aplicación móvil para registrar ingresos y gastos,
administrar facturas y obligaciones, consultar estadísticas y, en etapas
posteriores, gestionar presupuestos y metas de ahorro.

## Problema y pregunta

La organización mediante métodos manuales o herramientas dispersas puede
dificultar la planificación financiera, el seguimiento de pagos y el
ahorro.

**Pregunta problema:** "¿De qué manera el desarrollo de una aplicación
móvil para la gestión de finanzas personales puede facilitar el
registro, control y análisis de ingresos, gastos y obligaciones
financieras, contribuyendo a una mejor planificación económica de los
usuarios?"

## Entorno

-   Framework: Flutter.
-   Lenguaje: Dart.
-   Editor: Visual Studio Code.
-   Sistema de desarrollo: Windows, con PowerShell.
-   Pruebas: dispositivo Android conectado.
-   Base de datos local: SQLite mediante `sqflite` y `path`.
-   Estado: `provider`. Preferencias: `shared_preferences`.
-   Sincronización: Google Drive (`google_sign_in` 7 + API REST con `http`), `connectivity_plus`.
-   Recordatorios: `flutter_local_notifications`, `timezone`, `flutter_timezone`.
-   Actualizaciones: API de GitHub, `crypto`, `path_provider`, `open_filex`.
-   **Versión exacta de Flutter:** pendiente de verificar con
    `flutter --version`; no consta en el contexto disponible.
-   Ruta del proyecto: `C:\Users\isaac.deleon\finza`.

## Estructura

Desde octubre de 2026 la app está separada por carpetas, con el mismo
patrón que top-list. El detalle está en `ARCHITECTURE.md`.

``` text
finza/
├── lib/
│   ├── main.dart            arranque, providers y tema
│   ├── app_info.dart
│   ├── config/              AppConfig (finza_config.json)
│   ├── theme/               AppTheme claro/oscuro
│   ├── models/              Movimiento, Factura, FiltroMovimientos, Categorias, Actualizacion
│   ├── database/            DatabaseHelper (SQLite v3)
│   ├── providers/           FinanzasProvider, PreferenciasProvider
│   ├── services/            SyncService, DriveApi, RecordatoriosService, ActualizacionService
│   ├── screens/             HomeShell, Inicio, Movimientos, Estadísticas, Facturas,
│   │                        formularios, Papelera, Ajustes
│   ├── widgets/             tarjetas, filtros, banner, diálogos, acciones
│   └── utils/               formato, fechas, estado de facturas
├── test/
├── releases/                APK + latest.json (los genera release.ps1)
└── release.ps1
```

## Base de datos

La base está en **versión 3**. Además de sus campos, `movimientos` y
`facturas` tienen `uuid`, `actualizadoEn`, `eliminadoEn` y `purgado`, que
sirven para la sincronización y la papelera.

### Tabla `movimientos`

  Campo                  Tipo/uso
  ---------------------- -----------------------------------------
  `id`                   INTEGER, clave primaria local
  `uuid`                 TEXT, identidad entre celulares
  `tipo`                 TEXT (`Ingreso` o `Gasto`)
  `categoria`            TEXT
  `descripcion`          TEXT
  `monto`                REAL
  `fecha`                TEXT, ISO 8601
  `actualizadoEn`        TEXT, última modificación
  `eliminadoEn`          TEXT, nullable (papelera)
  `purgado`              INTEGER, 1 = eliminado definitivamente

### Tabla `facturas`

  Campo                  Tipo/uso
  ---------------------- -----------------------------------------
  `id`, `uuid`           igual que en movimientos
  `nombre`               TEXT
  `categoria`            TEXT
  `monto`                REAL
  `fechaVencimiento`     TEXT, ISO 8601
  `recurrente`           INTEGER, 1 o 0
  `frecuencia`           TEXT, nullable
  `estado`               TEXT, `Pendiente` o `Pagada`
  `actualizadoEn`, `eliminadoEn`, `purgado`   igual que en movimientos

Migraciones: v1→v2 crea `facturas` y v2→v3 agrega los campos nuevos y
asigna `uuid` a los datos existentes, sin perder nada.

**Regla importante:** nunca se borra una fila con `DELETE`. Eliminar
manda a la papelera (`eliminadoEn`) y vaciarla marca `purgado`. Así el
borrado también llega a los otros celulares.

## Funcionalidades implementadas

### Navegación y apariencia

-   `HomeShell` con barra inferior: Inicio, Movimientos, Estadísticas y Facturas.
-   Botón flotante según la pestaña (agregar movimiento o factura).
-   Ajustes: sincronización, tema (sistema, claro, oscuro), recordatorios,
    papelera, versión y buscar actualizaciones.
-   Colores de ingreso, gasto y alerta adaptados a modo oscuro (`ColoresFinza`).

### Movimientos

-   Crear, editar y eliminar (a la papelera, con "Deshacer").
-   Fecha elegible: ya no es siempre la de hoy.
-   Búsqueda, filtro por tipo y bottom sheet de filtros: periodo,
    categorías y orden. Los filtros se guardan.
-   Montos en formato colombiano al escribir (`80.000`, `80.000,50`).

### Estadísticas

-   Totales, saldo, porcentaje de ingresos vs. gastos y gastos por categoría.

### Facturas

-   Crear, editar y eliminar.
-   Chip de estado tocable (Pendiente o Pagada) y botón "Marcar pagada".
-   Recurrentes: al pagarla se crea la del siguiente periodo.
-   Estados visuales calculados: Pagada, Vencida, Vence hoy, Próxima y Pendiente.
-   Recordatorios el día antes y el día del vencimiento a las 9:00.
-   Banner al abrir la app si hay facturas vencidas o que vencen hoy.

### Papelera

-   Lo eliminado queda 30 días. Se puede restaurar, eliminar
    definitivamente o vaciar la papelera.

### Sincronización con Google Drive

-   Sin backend. Usa el permiso `drive.file`: Finza solo ve el archivo que
    crea, `finza_datos.json`.
-   Combina por registro: gana la modificación más reciente, así dos
    celulares no se pisan.
-   Se sincroniza al abrir y al volver a la app, después de cada cambio,
    al salir de la app, al deslizar hacia abajo y con "Sincronizar ahora".
-   **Sin conexión:** el teléfono es la fuente principal. Si no hay
    internet o Drive está caído, los cambios quedan pendientes (aunque se
    cierre la app) y se suben solos: reintentos cada vez más espaciados
    (de 15 s hasta 10 min) y en el momento en que vuelve la red.
-   Requiere configurar Google Cloud (ver README).

### Actualizaciones automáticas

-   `release.ps1` compila, publica el APK en `releases/` con su SHA-256 y
    hace push a `master`.
-   La app lee `releases/latest.json` del repo privado con un token de solo
    lectura, descarga el APK con progreso, verifica el SHA-256 y abre el
    instalador.
-   "Más tarde" pospone esa versión 24 horas.

### Moneda

Formato colombiano: punto para miles y coma para decimales. Ejemplos:
`$15.000,00`, `$1.500.000,50`, `$25.000,75`.

## Incidencias resueltas

1.  **Bloqueo Gradle (`buildLogic.lock`):** se detuvo Gradle y se
    ejecutaron `flutter clean` y `flutter pub get`.
2.  **NDK incompleto:** se eliminó la carpeta de NDK `28.2.13676358`,
    luego se ejecutaron limpieza, descarga de dependencias y
    `flutter run`. La app abrió en Android.
3.  **Error de widgets al guardar desde un diálogo:** se reemplazó
    `showDialog` por una pantalla dedicada con `Navigator.push`. El
    usuario confirmó que ya guarda sin error.
4.  **Factura no aparecía al volver al listado:** `_agregarFactura()` se
    ajustó para ejecutar `await _cargarFacturas()`. El usuario confirmó
    que ahora aparece correctamente.
5.  **El test por defecto de Flutter no compilaba** (usaba `MyApp`): se
    reemplazó por pruebas reales de Finza.
6.  **Crash al editar una factura vencida:** el selector de fecha tenía
    `firstDate` = hoy. Se corrigió en `FacturaFormScreen`.

## Estado actual y próximos pasos

**Hecho en octubre de 2026:** reorganización por carpetas, CRUD completo
de movimientos y facturas, papelera, filtros, facturas recurrentes,
recordatorios, tema oscuro, sincronización con Drive y actualizaciones
desde el repo privado, modo sin conexión con reintentos. `flutter analyze`
está limpio y hay 48 pruebas
automáticas (`flutter test`).

**Falta probar en el teléfono:** compilar el APK, el login con Google y la
sincronización real, las notificaciones y la instalación de una
actualización. En el entorno donde se escribió no había SDK de Android.

**Para que funcione la sincronización y el update** (una sola vez, ver
README): crear el keystore, configurar Google Cloud (Drive API, clientes
Android y Web), crear el token de GitHub y llenar `finza_config.json`.

Próximos pasos sugeridos:

1.  Metas de ahorro y presupuestos por categoría.
2.  Selector de periodo en Estadísticas.
3.  Al pagar una factura, ofrecer registrarla como gasto.

## Comandos útiles

Desde la carpeta del proyecto:

``` powershell
flutter --version
flutter pub get
flutter run --dart-define-from-file=finza_config.json
flutter test
flutter analyze
powershell -ExecutionPolicy Bypass -File .\release.ps1 -Cambios "Qué cambió"
```

Para limpiar si aparece un problema de caché:

``` powershell
flutter clean
flutter pub get
flutter run --dart-define-from-file=finza_config.json
```

## Pautas para continuar el desarrollo

-   El usuario está aprendiendo Flutter y necesita instrucciones paso a
    paso.
-   Indicar exactamente qué función o sección buscar y qué reemplazar.
-   Entregar código listo para copiar.
-   Realizar cambios graduales y probar cada etapa en el teléfono.
-   No inventar la versión de Flutter: confirmarla con
    `flutter --version`.
