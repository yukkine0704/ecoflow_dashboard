param(
    [string]$AvdName = "Medium_Tablet",
    [string]$DeviceId = "emulator-5554",
    [int]$BootTimeoutSeconds = 120
)

$ErrorActionPreference = "Stop"

function Write-Step([string]$message) {
    Write-Host "[run-tablet] $message"
}

if (-not $env:ANDROID_SDK_ROOT -or -not (Test-Path $env:ANDROID_SDK_ROOT)) {
    $localProperties = Join-Path $PSScriptRoot "..\android\local.properties"
    if (Test-Path $localProperties) {
        $sdkLine = Select-String -Path $localProperties -Pattern "^sdk\.dir=" | Select-Object -First 1
        if ($sdkLine) {
            $sdkPath = $sdkLine.Line.Substring("sdk.dir=".Length).Replace("\\", "\")
            $env:ANDROID_SDK_ROOT = $sdkPath
        }
    }
}

if (-not $env:ANDROID_SDK_ROOT -or -not (Test-Path $env:ANDROID_SDK_ROOT)) {
    throw "ANDROID_SDK_ROOT no esta configurado correctamente."
}

$platformTools = Join-Path $env:ANDROID_SDK_ROOT "platform-tools"
$emulatorTools = Join-Path $env:ANDROID_SDK_ROOT "emulator"
$adb = Join-Path $platformTools "adb.exe"
$emulator = Join-Path $emulatorTools "emulator.exe"

if (-not (Test-Path $adb)) { throw "No se encontro adb en $adb" }
if (-not (Test-Path $emulator)) { throw "No se encontro emulator en $emulator" }

$pathParts = $env:PATH -split ";"
$pathParts = @($platformTools, $emulatorTools) + ($pathParts | Where-Object { $_ -and ($_ -ne "C:\adb") })
$env:PATH = ($pathParts | Select-Object -Unique) -join ";"

Write-Step "Reiniciando adb server..."
& $adb kill-server | Out-Null
& $adb start-server | Out-Null

Write-Step "Verificando emulador '$DeviceId'..."
$deviceList = & $adb devices
$deviceLine = $deviceList | Where-Object { $_ -match "^$DeviceId\s+device$" }

if (-not $deviceLine) {
    Write-Step "Lanzando AVD '$AvdName'..."
    Start-Process -FilePath $emulator -ArgumentList "-avd", $AvdName -WindowStyle Hidden

    $deadline = (Get-Date).AddSeconds($BootTimeoutSeconds)
    do {
        Start-Sleep -Seconds 2
        $devices = & $adb devices
        $ready = $devices | Where-Object { $_ -match "^$DeviceId\s+device$" }
    } while (-not $ready -and (Get-Date) -lt $deadline)

    if (-not $ready) {
        throw "El emulador no quedo listo en $BootTimeoutSeconds segundos."
    }
}

Write-Step "Ejecutando flutter run en $DeviceId..."
flutter run -d $DeviceId
