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
-   **Versión exacta de Flutter:** pendiente de verificar con
    `flutter --version`; no consta en el contexto disponible.
-   Ruta del proyecto: `C:\Users\isaac.deleon\finza`.

## Estructura conocida

``` text
finza/
└── lib/
    ├── main.dart
    ├── models/
    │   ├── movimiento.dart
    │   └── factura.dart
    └── database/
        └── database_helper.dart
```

`main.dart` contiene la interfaz y pantallas; `models` define los
objetos; `database_helper.dart` administra SQLite.

## Base de datos

Dependencias instaladas:

``` powershell
flutter pub add sqflite
flutter pub add path
flutter pub get
```

La base de datos está en **versión 2** e incluye:

### Tabla `movimientos`

  Campo           Tipo/uso
  --------------- -----------------------------------------
  `id`            INTEGER, clave primaria autoincremental
  `tipo`          TEXT
  `categoria`     TEXT
  `descripcion`   TEXT
  `monto`         REAL
  `fecha`         TEXT, ISO 8601

### Tabla `facturas`

  Campo                Tipo/uso
  -------------------- -----------------------------------------
  `id`                 INTEGER, clave primaria autoincremental
  `nombre`             TEXT
  `categoria`          TEXT
  `monto`              REAL
  `fechaVencimiento`   TEXT, ISO 8601
  `recurrente`         INTEGER, 1 o 0
  `frecuencia`         TEXT, nullable
  `estado`             TEXT, valor inicial `Pendiente`

La migración desde una versión anterior crea la tabla de facturas si
`oldVersion < 2`.

### Métodos de persistencia

Movimientos: `insertarMovimiento`, `obtenerMovimientos`,
`actualizarMovimiento`, `eliminarMovimiento`.

Facturas: `insertarFactura`, `obtenerFacturas`, `actualizarFactura`,
`eliminarFactura`.

También existe `cerrarBaseDeDatos()`.

## Modelos

`Movimiento` tiene `id` opcional, `tipo`, `categoria`, `descripcion`,
`monto` y `fecha`; implementa `toMap()` y `Movimiento.fromMap()`.

`Factura` tiene `id` opcional, `nombre`, `categoria`, `monto`,
`fechaVencimiento`, `recurrente`, `frecuencia` opcional y `estado`;
implementa `toMap()` y `Factura.fromMap()`. El booleano de recurrencia
se guarda como entero en SQLite.

## Funcionalidades implementadas

### Inicio y navegación

-   Pantalla principal `InicioScreen`.
-   Resumen de ingresos, gastos y saldo calculado a partir de
    movimientos.
-   Barra inferior: Inicio, Movimientos, Estadísticas y Facturas.
-   Botón flotante **Agregar** en Inicio.

### Movimientos

-   Formulario dedicado `AgregarMovimientoScreen`.
-   Guardado en SQLite.
-   Búsqueda por descripción o categoría.
-   Filtros Todos, Ingreso y Gasto.
-   Presentación de movimientos recientes.
-   Ingresos en verde y gastos en rojo.

### Estadísticas

-   Totales de ingresos y gastos.
-   Saldo.
-   Comparación visual mediante barras.
-   Gastos agrupados por categoría.
-   Conteo de movimientos.
-   Refresco de datos.
-   Indicadores verdes para ingresos y rojos para gastos.

### Facturas

-   Formulario `AgregarFacturaScreen` con nombre, categoría, monto,
    vencimiento y recurrencia.
-   Categorías: Servicios, Vivienda, Internet, Telefonía, Suscripciones,
    Transporte y Otros.
-   Frecuencias: Semanal, Mensual, Trimestral y Anual.
-   Nuevas facturas se guardan con estado `Pendiente`.
-   Listado de pendientes y pagadas.
-   Resumen del monto pendiente y cantidad de facturas pendientes.
-   Acción **Marcar pagada**.
-   Actualización del listado después de crear una factura.
-   Estados visuales: Pagada, Vencida, Vence hoy, Próxima y Pendiente.

### Lógica de vencimientos

`_obtenerEstadoFactura()` muestra: - `Pagada` si ese es el estado
almacenado. - `Vencida` si la fecha pasó. - `Vence hoy` si vence hoy. -
`Próxima` si vence en los próximos tres días. - `Pendiente` en los demás
casos.

El estado de vencimiento se calcula para la interfaz y no necesariamente
cambia el valor guardado.

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

## Estado actual y próximos pasos

**Confirmado por el usuario:** guardar movimientos, guardar y listar
facturas, marcar facturas como pagadas y refrescar el listado tras crear
una factura funcionan.

Se propuso temporalmente una función/botón para crear una factura de
prueba vencida (vencimiento 1 de septiembre de 2026). Debe probarse y
retirarse al terminar.

Próximos pasos sugeridos: 1. Verificar la etiqueta Vencida con una fecha
pasada. 2. Retirar el botón y la función temporales. 3. Implementar
edición y eliminación de facturas para completar el CRUD. 4. Continuar
con recordatorios/notificaciones, pagos recurrentes y metas de ahorro.

## Comandos útiles

Desde la carpeta del proyecto:

``` powershell
flutter --version
flutter pub get
flutter run
```

Para limpiar si aparece un problema de caché:

``` powershell
flutter clean
flutter pub get
flutter run
```

## Pautas para continuar el desarrollo

-   El usuario está aprendiendo Flutter y necesita instrucciones paso a
    paso.
-   Indicar exactamente qué función o sección buscar y qué reemplazar.
-   Entregar código listo para copiar.
-   Realizar cambios graduales y probar cada etapa en el teléfono.
-   No inventar la versión de Flutter: confirmarla con
    `flutter --version`.
