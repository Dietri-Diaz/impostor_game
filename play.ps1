# play.ps1
# Arranca el emulador (si no está corriendo) y lanza la app.
#
# Uso:
#   .\play.ps1              -> modo debug (hot reload activado, ideal para iterar)
#   .\play.ps1 -Release     -> modo release (rápido, sin warnings, sin hot reload)
#   .\play.ps1 -Emulator Pixel_10  -> usar otro emulador (default: Pixel_6)
#
# Una vez la app corra:
#   r  = hot reload   (aplica cambios sin reiniciar el estado del juego)
#   R  = hot restart  (reinicia la app desde cero, conserva el proceso)
#   q  = quit
#
# Solo en MODO DEBUG funcionan r y R.

param(
    [switch]$Release,
    [string]$Emulator = "Pixel_6"
)

$ErrorActionPreference = "Stop"

function Write-Step($msg) {
    Write-Host ""
    Write-Host "==> $msg" -ForegroundColor Cyan
}

function Has-AndroidDevice {
    $output = & flutter devices 2>&1 | Out-String
    return $output -match "android-x"
}

function Get-AndroidEmulatorId {
    $output = & flutter devices 2>&1 | Out-String
    if ($output -match "(emulator-\d+)") {
        return $matches[1]
    }
    return $null
}

# ---- Paso 1: arrancar el emulador si no está corriendo ----
if (Has-AndroidDevice) {
    Write-Step "Emulador Android ya está corriendo"
}
else {
    Write-Step "Lanzando emulador '$Emulator'..."
    Start-Process -NoNewWindow -FilePath "flutter" -ArgumentList @("emulators", "--launch", $Emulator) | Out-Null

    Write-Host "Esperando a que arranque (puede tardar 30-90 seg la primera vez)..." -ForegroundColor DarkGray
    $timeout = 180
    $elapsed = 0
    while ($elapsed -lt $timeout) {
        Start-Sleep -Seconds 5
        $elapsed += 5
        Write-Host "  esperando... ($elapsed s)" -ForegroundColor DarkGray
        if (Has-AndroidDevice) {
            Write-Host "Emulador listo!" -ForegroundColor Green
            break
        }
    }

    if (-not (Has-AndroidDevice)) {
        Write-Host "ERROR: el emulador no apareció después de $timeout segundos." -ForegroundColor Red
        Write-Host "Verifica que el AVD '$Emulator' existe en Android Studio Device Manager." -ForegroundColor Red
        exit 1
    }
}

# ---- Paso 2: identificar el ID del emulador ----
$emulatorId = Get-AndroidEmulatorId
if (-not $emulatorId) {
    Write-Host "ERROR: no se pudo identificar el ID del emulador." -ForegroundColor Red
    exit 1
}

# ---- Paso 3: correr la app ----
if ($Release) {
    Write-Step "Compilando y lanzando en MODO RELEASE en $emulatorId"
    Write-Host "Tarda ~2 min la primera vez. Después la app es rápida pero NO tendrás hot reload." -ForegroundColor DarkGray
    & flutter run --release -d $emulatorId
}
else {
    Write-Step "Compilando y lanzando en MODO DEBUG en $emulatorId"
    Write-Host "Una vez arranque, presiona:" -ForegroundColor Yellow
    Write-Host "  r  para hot reload (cambios sin perder el estado)" -ForegroundColor Yellow
    Write-Host "  R  para hot restart (reiniciar la app)" -ForegroundColor Yellow
    Write-Host "  q  para salir" -ForegroundColor Yellow
    & flutter run -d $emulatorId
}
