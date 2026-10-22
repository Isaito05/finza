# Finza

**Controla tu dinero, alcanza tus metas.**

App Android para manejar finanzas personales: registrar ingresos y gastos,
llevar el control de facturas y sus vencimientos, y ver estadísticas.
Proyecto universitario: *"Finza: Aplicación móvil para la gestión y control de
las finanzas personales mediante el seguimiento de ingresos, gastos, facturas y
metas de ahorro"*.

No tiene backend. Los datos viven en el teléfono (SQLite) y, si conectas tu
cuenta de Google, se sincronizan con un archivo en tu propio Google Drive. No
se distribuye por Play Store: el APK se publica en este repo y la app se
actualiza sola.

**Antes de cambiar la app, leer [`ARCHITECTURE.md`](ARCHITECTURE.md):**
estructura, flujo de datos, sincronización y reglas de negocio.
Contexto del proyecto (decisiones, incidencias, próximos pasos):
[`Contexto_Finza.md`](Contexto_Finza.md).

## Funcionalidades
- **Inicio:** saldo, ingresos, gastos, aviso de facturas por vencer y movimientos recientes.
- **Movimientos:**
  - crear, **editar** y eliminar ingresos y gastos, **con fecha elegible**;
  - búsqueda por descripción o categoría;
  - filtros por tipo, **periodo** (este mes, mes pasado, últimos 3 meses o un rango), **categorías** y **orden**; se guardan al cerrar la app.
- **Estadísticas:** totales, saldo, ingresos vs. gastos y gastos por categoría.
- **Facturas:**
  - crear, **editar** y **eliminar**;
  - estados según la fecha: *Vencida*, *Vence hoy*, *Próxima* (3 días) y *Pendiente*;
  - chip de estado tocable para marcar pagada o pendiente;
  - **recurrentes:** al pagarla se crea sola la del siguiente periodo (semanal, mensual, trimestral o anual).
- **Papelera:** lo eliminado queda 30 días para restaurarlo; al eliminar aparece "Deshacer".
- **Recordatorios:** notificación el día antes y el día del vencimiento de cada factura, a las 9:00. Banner al abrir la app si hay facturas vencidas o que vencen hoy.
- **Sincronización con Google Drive:** respaldo automático y los mismos datos en varios celulares. **Funciona sin conexión:** si no hay internet o Drive no responde, todo queda guardado en el teléfono como pendiente y se sube solo cuando vuelve el servicio (reintentos automáticos y al recuperar la red).
- **Tema claro y oscuro** (o el del sistema).
- **Actualizaciones:** al abrir, la app revisa si hay una versión nueva en este repo, la descarga, verifica que esté completa y abre el instalador.

## Configuración (una sola vez)

La app lee dos valores privados de `finza_config.json`, que no se sube al repo:

```powershell
Copy-Item finza_config.example.json finza_config.json
```

```json
{
  "FINZA_GOOGLE_CLIENT_ID": "123456789-abc.apps.googleusercontent.com",
  "FINZA_GITHUB_TOKEN": "github_pat_..."
}
```

Si falta alguno, la app funciona igual, pero sin sincronización (Ajustes dice
"No disponible en esta versión") o sin actualizaciones.

### Google Cloud: sincronización con Drive

En [console.cloud.google.com](https://console.cloud.google.com), con un proyecto para Finza:

1. **APIs y servicios → Biblioteca:** habilita **Google Drive API**.
2. **Google Auth Platform → Branding:** nombre "Finza" y tu correo de soporte.
3. **Audience:** tipo *Externo*. Mientras esté *En prueba*, agrega como usuarios de prueba los correos que van a usar la app. En modo de prueba Google puede pedir el permiso de nuevo cada 7 días (en Ajustes aparece "Dar permiso"). Para evitarlo, pásala a *En producción*: `drive.file` es un permiso no sensible, así que en principio no requiere verificación de Google.
4. **Data Access:** agrega el scope `https://www.googleapis.com/auth/drive.file`.
5. **Clients → Crear cliente → Android:**
   - Package name: `com.example.finza`.
   - SHA-1: el de tu keystore de release:
     ```powershell
     keytool -list -v -keystore $env:USERPROFILE\finza-release.jks -alias finza
     ```
   - Para probar con `flutter run`, crea **otro** cliente Android con el SHA-1 de debug: `keytool -list -v -keystore $env:USERPROFILE\.android\debug.keystore -alias androiddebugkey -storepass android`.
6. **Clients → Crear cliente → Aplicación web** (sin URIs). Su **Client ID** es el que va en `FINZA_GOOGLE_CLIENT_ID`. En Android, `google_sign_in` lo exige aunque no haya servidor.

**Qué ve Finza de tu Drive:** con `drive.file`, solo los archivos que ella misma
crea. Guarda uno, `finza_datos.json`, en la raíz de tu Drive. Si lo borras,
Finza lo vuelve a crear en la próxima sincronización con los datos del teléfono.

### GitHub: actualizaciones desde el repo privado

1. GitHub → Settings → Developer settings → **Fine-grained tokens** → Generate new token.
2. *Repository access:* **Only select repositories** → `Isaito05/finza`.
3. *Permissions → Repository permissions → Contents:* **Read-only**. Nada más.
4. Elige la expiración más larga y pon el token en `FINZA_GITHUB_TOKEN`.

El token queda dentro del APK. Como solo puede *leer* este repo, quien lo
extraiga solo podría ver el código y los APK. **Si el token vence**, las
versiones instaladas dejan de ver actualizaciones: genera otro, publica una
versión e instálala a mano una vez.

### Llave de firma

Android solo instala una actualización encima si viene firmada con la **misma
llave**. Sigue [`android/key.properties.example`](android/key.properties.example)
para crear el `.jks` y `android/key.properties`. Guarda el `.jks` y sus
contraseñas con respaldo y **fuera del repo**. Su SHA-1 es el que registras en
Google Cloud (paso 5).

## Correr en local

```powershell
flutter pub get
flutter run --dart-define-from-file=finza_config.json
```

En VS Code, la configuración **"Finza"** de `.vscode/launch.json` ya pasa el
archivo. Sin él, usa "Finza (sin configuración)".

Pruebas: `flutter test` (base de datos real con `sqflite_common_ffi`,
sincronización contra un Drive simulado, actualizaciones e interfaz).

## Instalar en el celular

La primera vez, el APK se instala a mano. Después, la app se actualiza sola.

- **Por cable:** con el celular conectado, `flutter install --release` (o copia `releases/finza.apk`).
- **Desde el celular:** abre `https://github.com/Isaito05/finza/blob/master/releases/finza.apk` con tu sesión de GitHub iniciada en el navegador y toca *Download raw file*.

> Si tenías una versión instalada con `flutter run` o firmada con otra llave,
> desinstálala antes. Si ya conectaste Drive, tus datos vuelven al conectar la
> misma cuenta; si no, se pierden al desinstalar.

## Publicar una versión nueva

Desde Windows, en la raíz del repo, en `master` y sin cambios pendientes:

```powershell
powershell -ExecutionPolicy Bypass -File .\release.ps1 -Cambios "Arregla el listado de facturas"
powershell -ExecutionPolicy Bypass -File .\release.ps1 -Version 1.2.0 -Cambios "Metas de ahorro"
```

- `-Cambios` (obligatorio): el texto que ve el usuario en el diálogo de actualización.
- `-Version X.Y.Z` (opcional): si se omite, se mantiene y solo sube el build (`+N`).
- `-SinPush`: compila y hace commit sin publicar.

Qué hace [`release.ps1`](release.ps1):
1. Verifica que estés en `master`, sin cambios pendientes, con `android/key.properties` y `finza_config.json`.
2. Sube `version:` en `pubspec.yaml`: el `+N` siempre y el `X.Y.Z` solo si lo pasaste.
3. Compila con `flutter build apk --release --dart-define-from-file=finza_config.json` (solo ARM, que cubre prácticamente todos los celulares). Si falla, revierte la versión.
4. Deja el APK en `releases/` como `Finza-vX.Y.Z-N.apk` y `finza.apk`, y escribe `releases/latest.json` con la versión, el SHA-256, el tamaño y los cambios.
5. Hace commit `Release vX.Y.Z+N` y `git push origin master`.

### Cómo se actualiza la app

1. Al abrir, [`ActualizacionService`](lib/services/actualizacion_service.dart) lee `releases/latest.json` con la API de GitHub y el token. Sin token, usa la URL pública, que solo sirve si el repo es público.
2. Si su `versionCode` es mayor que el build instalado, muestra las novedades.
3. **Actualizar:** descarga el APK dentro de la app con barra de progreso, verifica el SHA-256 y abre el instalador. La primera vez, Android pide permitir que Finza instale apps.
4. **Más tarde:** no vuelve a preguntar por esa versión en 24 horas. En **Ajustes → Buscar actualizaciones** se puede revisar en cualquier momento.

> Cada APK pesa unos 15–20 MB y queda en el historial de git. Si el repo crece
> demasiado, la alternativa es moverlos a GitHub Releases.

## Estructura

```
lib/
  main.dart            arranque: providers, servicios y tema
  app_info.dart        versión instalada
  config/              AppConfig (valores de finza_config.json)
  theme/               AppTheme claro/oscuro y ColoresFinza
  models/              Movimiento, Factura, FiltroMovimientos, Categorias, Actualizacion
  database/            DatabaseHelper (SQLite, versión 3)
  providers/           FinanzasProvider (datos) y PreferenciasProvider (ajustes del teléfono)
  services/            SyncService + DriveApi, RecordatoriosService, ActualizacionService
  screens/             HomeShell y una pantalla por archivo
  widgets/             componentes reutilizables (tarjetas, filtros, banner, diálogos)
  utils/               formato de dinero y fechas, estado de facturas
test/                  pruebas
releases/              APK publicado + latest.json (los genera release.ps1)
```
