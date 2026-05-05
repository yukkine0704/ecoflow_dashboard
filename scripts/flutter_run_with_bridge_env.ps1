param(
  [string]$EnvPath = "D:\.DEV\.Flutter\ecoflow_dashboard\bridge\.env"
)

$ErrorActionPreference = "Stop"

function Parse-DotEnvValue {
  param([string]$Value)
  $trimmed = $Value.Trim()
  if ($trimmed.Length -ge 2) {
    $first = $trimmed.Substring(0, 1)
    $last = $trimmed.Substring($trimmed.Length - 1, 1)
    if (($first -eq '"' -and $last -eq '"') -or ($first -eq "'" -and $last -eq "'")) {
      return $trimmed.Substring(1, $trimmed.Length - 2)
    }
  }
  return $trimmed
}

if (-not (Test-Path -LiteralPath $EnvPath)) {
  throw "Bridge .env not found: $EnvPath"
}

$envMap = @{}
foreach ($line in Get-Content -LiteralPath $EnvPath) {
  $trimmed = $line.Trim()
  if ($trimmed.Length -eq 0 -or $trimmed.StartsWith("#")) {
    continue
  }
  if ($trimmed.StartsWith("export ")) {
    $trimmed = $trimmed.Substring("export ".Length).TrimStart()
  }
  $separator = $trimmed.IndexOf("=")
  if ($separator -le 0) {
    continue
  }
  $key = $trimmed.Substring(0, $separator).Trim()
  $value = Parse-DotEnvValue $trimmed.Substring($separator + 1)
  $envMap[$key] = $value
}

$required = @(
  "ECOFLOW_APP_EMAIL",
  "ECOFLOW_APP_PASSWORD",
  "ECOFLOW_OPEN_ACCESS_KEY",
  "ECOFLOW_OPEN_SECRET_KEY"
)

$missing = @()
foreach ($key in $required) {
  if (-not $envMap.ContainsKey($key) -or [string]::IsNullOrWhiteSpace($envMap[$key])) {
    $missing += $key
  }
}
if ($missing.Count -gt 0) {
  throw "Missing required bridge .env keys: $($missing -join ', ')"
}

$defineKeys = @(
  "ECOFLOW_APP_EMAIL",
  "ECOFLOW_APP_PASSWORD",
  "ECOFLOW_OPEN_ACCESS_KEY",
  "ECOFLOW_OPEN_SECRET_KEY",
  "ECOFLOW_BASE_URL",
  "ECOFLOW_OPEN_BASE_URL"
)

$defines = @()
foreach ($key in $defineKeys) {
  if ($envMap.ContainsKey($key) -and -not [string]::IsNullOrWhiteSpace($envMap[$key])) {
    $defines += "--dart-define=$key=$($envMap[$key])"
  }
}

Write-Host "Passing dart-defines from ${EnvPath}:"
foreach ($key in $defineKeys) {
  if ($envMap.ContainsKey($key) -and -not [string]::IsNullOrWhiteSpace($envMap[$key])) {
    Write-Host "  $key=***"
  }
}
Write-Host "Starting flutter run. Use -d <deviceId> after the script name if needed."

flutter run @defines @args
