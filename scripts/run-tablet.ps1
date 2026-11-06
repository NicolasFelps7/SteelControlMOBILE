param([string]$DeviceId = "")
$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  throw "Instale o Flutter e adicione-o ao PATH antes de continuar."
}
flutter pub get
if ($LASTEXITCODE -ne 0) { throw "Falha ao instalar dependencias." }
flutter devices
if ($LASTEXITCODE -ne 0) { throw "Falha ao consultar dispositivos." }
$flutterArgs = @("run", "--dart-define=API_URL=https://web-production-6682df.up.railway.app")
if ($DeviceId) { $flutterArgs += @("-d", $DeviceId) }
& flutter @flutterArgs
if ($LASTEXITCODE -ne 0) { throw "Falha ao iniciar o aplicativo." }
