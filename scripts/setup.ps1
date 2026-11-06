$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  throw "Instale o Flutter e o Android Studio e adicione flutter ao PATH."
}
flutter doctor
flutter pub get
if ($LASTEXITCODE -ne 0) { throw "Falha ao instalar dependencias." }
Write-Host "Pronto. Ative a depuracao USB no Android e execute scripts\run-tablet.ps1."
