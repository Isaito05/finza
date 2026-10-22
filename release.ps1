# Publica una version nueva de Finza para que los celulares la vean como
# actualizacion. Se corre en Windows (PowerShell), desde la raiz del repo:
#
#   powershell -ExecutionPolicy Bypass -File .\release.ps1 -Cambios "Arregla X"
#   powershell -ExecutionPolicy Bypass -File .\release.ps1 -Version 1.1.0 -Cambios "Metas de ahorro"
#
#   -Version   opcional (X.Y.Z). Si se omite, se mantiene y solo sube el build (+N).
#   -Cambios   obligatorio. Es el texto que ve el usuario en el dialogo de actualizacion.
#   -SinPush   compila y commitea, pero no hace push (la version no se publica todavia).
#   -FirmaDebug  permite publicar sin android/key.properties (no recomendado).
#
# Necesita finza_config.json (copia de finza_config.example.json) con el
# Client ID de Google (sincronizacion con Drive) y el token de GitHub (para
# que la app baje actualizaciones del repo privado).
#
# Que hace:
#   1. Sube "version:" en pubspec.yaml (el +N siempre, el X.Y.Z solo si se paso).
#   2. flutter pub get + flutter build apk --release (con finza_config.json).
#   3. Copia el APK a releases/ (versionado + finza.apk) y escribe releases/latest.json
#      con su SHA-256, que la app verifica despues de descargarlo.
#   4. Commit y push a master. Desde ese momento la app lo detecta al abrirse.
#
# El archivo se mantiene sin tildes a proposito: PowerShell 5.1 lee los .ps1
# sin BOM como ANSI y las tildes saldrian corruptas.

param(
    [string]$Version = "",
    [Parameter(Mandatory = $true)][string]$Cambios,
    [switch]$SinPush,
    [switch]$FirmaDebug
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$Repo = "Isaito05/finza"
$Rama = "master"
$Pubspec = Join-Path $PSScriptRoot "pubspec.yaml"
$Config = Join-Path $PSScriptRoot "finza_config.json"
$ReleasesDir = Join-Path $PSScriptRoot "releases"
$Utf8SinBom = New-Object System.Text.UTF8Encoding $false

function Fallar([string]$mensaje) {
    Write-Host $mensaje -ForegroundColor Red
    exit 1
}

if ($Version -and $Version -notmatch '^\d+\.\d+\.\d+$') {
    Fallar "Version invalida: '$Version' (esperado X.Y.Z, ej: 1.1.0)"
}

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Fallar "flutter no esta en el PATH."
}

$ramaActual = (git rev-parse --abbrev-ref HEAD).Trim()
if ($ramaActual -ne $Rama) {
    Fallar "Estas en la rama '$ramaActual'. Las versiones se publican desde '$Rama' (la app lee releases/latest.json de esa rama)."
}

if (git status --porcelain) {
    Fallar "Hay cambios sin commitear. Haz commit (o descartalos) antes de publicar, para que el APK corresponda al codigo del repo."
}

if (-not (Test-Path (Join-Path $PSScriptRoot "android\key.properties")) -and -not $FirmaDebug) {
    Fallar ("Falta android\key.properties: el APK saldria firmado con la llave de debug de este PC " +
        "y las actualizaciones no se podrian instalar encima si se compila en otro. " +
        "Ver android\key.properties.example, o usa -FirmaDebug si sabes lo que haces.")
}

if (-not (Test-Path $Config)) {
    Fallar ("Falta finza_config.json. Copia finza_config.example.json y completa el Client ID de Google " +
        "y el token de GitHub; sin eso el APK no sincroniza ni encuentra actualizaciones.")
}
try {
    $valores = Get-Content $Config -Raw | ConvertFrom-Json
} catch {
    Fallar "finza_config.json no es un JSON valido."
}
if (-not $valores.FINZA_GOOGLE_CLIENT_ID) {
    Write-Host "Aviso: FINZA_GOOGLE_CLIENT_ID esta vacio; esta version no podra sincronizar con Drive." -ForegroundColor Yellow
}
if (-not $valores.FINZA_GITHUB_TOKEN) {
    Write-Host "Aviso: FINZA_GITHUB_TOKEN esta vacio; si el repo es privado, la app no vera las actualizaciones." -ForegroundColor Yellow
}

# --- 1. Version ---
$contenido = [System.IO.File]::ReadAllText($Pubspec)
$patron = '(?m)^version:[ \t]*(\d+\.\d+\.\d+)\+(\d+)[ \t]*(?=\r?$)'
$coincidencia = [regex]::Match($contenido, $patron)
if (-not $coincidencia.Success) {
    Fallar "No se encontro 'version: X.Y.Z+N' en pubspec.yaml"
}

$versionActual = $coincidencia.Groups[1].Value
$buildActual = [int]$coincidencia.Groups[2].Value
$versionNueva = if ($Version) { $Version } else { $versionActual }
$buildNuevo = $buildActual + 1

Write-Host "== Version actual: $versionActual+$buildActual"
Write-Host "== Version nueva:  $versionNueva+$buildNuevo"

$contenido = [regex]::Replace($contenido, $patron, "version: $versionNueva+$buildNuevo")
[System.IO.File]::WriteAllText($Pubspec, $contenido, $Utf8SinBom)

# --- 2. Compilar ---
Write-Host "== Compilando APK release =="
flutter pub get
if ($LASTEXITCODE -ne 0) { git checkout -- pubspec.yaml pubspec.lock; Fallar "Fallo flutter pub get." }

# Solo ARM: cubre practicamente todos los celulares y deja el APK mas liviano.
flutter build apk --release --target-platform android-arm,android-arm64 --dart-define-from-file=finza_config.json
if ($LASTEXITCODE -ne 0) { git checkout -- pubspec.yaml pubspec.lock; Fallar "Fallo la compilacion. Se revirtio el cambio de version." }

$apkCompilado = Join-Path $PSScriptRoot "build\app\outputs\flutter-apk\app-release.apk"
if (-not (Test-Path $apkCompilado)) {
    Fallar "No se encontro el APK en $apkCompilado"
}

# --- 3. releases/ ---
New-Item -ItemType Directory -Force -Path $ReleasesDir | Out-Null
Get-ChildItem $ReleasesDir -Filter "Finza-v*.apk" | Remove-Item

$nombreApk = "Finza-v$versionNueva-$buildNuevo.apk"
Copy-Item $apkCompilado (Join-Path $ReleasesDir $nombreApk)
# Copia con nombre fijo para el link de descarga del README. Git guarda el
# contenido una sola vez, asi que no duplica el peso del repo.
Copy-Item $apkCompilado (Join-Path $ReleasesDir "finza.apk") -Force

$latest = [ordered]@{
    version     = $versionNueva
    versionCode = $buildNuevo
    apk         = "releases/$nombreApk"
    sha256      = (Get-FileHash $apkCompilado -Algorithm SHA256).Hash.ToLower()
    tamano      = (Get-Item $apkCompilado).Length
    changelog   = $Cambios
    fecha       = (Get-Date).ToString("yyyy-MM-dd")
}
$json = $latest | ConvertTo-Json
[System.IO.File]::WriteAllText((Join-Path $ReleasesDir "latest.json"), $json + "`n", $Utf8SinBom)

$tamanoMb = [math]::Round((Get-Item $apkCompilado).Length / 1MB, 1)
Write-Host "== APK: releases\$nombreApk ($tamanoMb MB)"

# --- 4. Commit y push ---
git add pubspec.yaml pubspec.lock releases
git commit -m "Release v$versionNueva+$buildNuevo" -m $Cambios
if ($LASTEXITCODE -ne 0) { Fallar "Fallo el commit." }

if ($SinPush) {
    Write-Host "== Listo (sin push). Cuando quieras publicarla: git push origin $Rama" -ForegroundColor Yellow
    exit 0
}

git push origin $Rama
if ($LASTEXITCODE -ne 0) { Fallar "Fallo el push. El commit quedo local: reintenta con 'git push origin $Rama'." }

Write-Host "== Publicada v$versionNueva+$buildNuevo ==" -ForegroundColor Green
Write-Host "Los celulares con una version anterior la veran al abrir Finza (o en Ajustes > Buscar actualizaciones)."
