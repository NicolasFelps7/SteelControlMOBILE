$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path

function Invoke-Native {
  param([Parameter(Mandatory=$true)][string]$File,[Parameter(ValueFromRemainingArguments=$true)][string[]]$NativeArgs)
  & $File @NativeArgs
  if ($LASTEXITCODE -ne 0) { throw "Falha: $File $($NativeArgs -join ' ')" }
}

Write-Host ''
Write-Host '===================================================' -ForegroundColor DarkGray
Write-Host ' SteelControl Mobile - Build Seguro Nível 9' -ForegroundColor Cyan
Write-Host '===================================================' -ForegroundColor DarkGray

$domain = (Read-Host 'Domínio da API, sem https://').Trim().ToLowerInvariant()
if ($domain -notmatch '^[a-z0-9](?:[a-z0-9.-]*[a-z0-9])$' -or $domain -notmatch '\.') {
  throw 'Domínio inválido.'
}

$manifest = Join-Path $Root 'android\app\src\main\AndroidManifest.xml'
$manifestText = Get-Content $manifest -Raw
if ($manifestText -notmatch 'usesCleartextTraffic="false"') {
  throw 'O AndroidManifest de release não está bloqueando tráfego HTTP.'
}

Push-Location $Root
try {
  Invoke-Native flutter clean
  Invoke-Native flutter pub get
  Invoke-Native flutter analyze
  Invoke-Native flutter test
  Invoke-Native flutter build apk --release "--dart-define=API_URL=https://$domain"
} finally { Pop-Location }

$apk = Join-Path $Root 'build\app\outputs\flutter-apk\app-release.apk'
if (-not (Test-Path $apk)) { throw 'APK não foi gerado.' }
$hash = (Get-FileHash $apk -Algorithm SHA256).Hash
Write-Host ''
Write-Host 'APK seguro gerado.' -ForegroundColor Green
Write-Host $apk
Write-Host "SHA-256: $hash" -ForegroundColor DarkGray

