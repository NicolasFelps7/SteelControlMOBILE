$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  throw "Flutter nao foi encontrado. Execute PREPARAR_APP.ps1 depois de instalar o Flutter."
}

Write-Host "Dispositivos encontrados:" -ForegroundColor Cyan
flutter devices

$ip = Read-Host "Digite o IPv4 do computador que esta rodando o backend (ex.: 192.168.0.10)"
if ($ip -notmatch '^\d{1,3}(\.\d{1,3}){3}$') {
  throw "IPv4 invalido. Rode ipconfig no computador e informe o Endereco IPv4."
}

$apiUrl = "http://${ip}:3000"
Write-Host "Iniciando o SteelControl conectado em $apiUrl" -ForegroundColor Green
flutter run --dart-define="API_URL=$apiUrl"
