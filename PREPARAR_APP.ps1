$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host " STEELCONTROL MOBILE - PREPARACAO DO FLUTTER" -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  Write-Host "Flutter nao foi encontrado no PATH." -ForegroundColor Red
  Write-Host "Instale o Flutter e o Android Studio antes de continuar:" -ForegroundColor Yellow
  Write-Host "https://docs.flutter.dev/get-started/install/windows/mobile"
  exit 1
}

Set-Location $PSScriptRoot

flutter doctor
if ($LASTEXITCODE -ne 0) {
  throw "O flutter doctor encontrou um erro que impede a preparacao."
}

flutter create . --platforms=android --org br.com.steelcontrol --project-name steelcontrol_mobile
if ($LASTEXITCODE -ne 0) {
  throw "Nao foi possivel gerar a estrutura Android."
}

$manifestPath = Join-Path $PSScriptRoot "android\app\src\main\AndroidManifest.xml"
$manifest = Get-Content -Raw $manifestPath
if ($manifest -notmatch 'android.permission.INTERNET') {
  $manifest = $manifest.Replace('<manifest xmlns:android="http://schemas.android.com/apk/res/android">', '<manifest xmlns:android="http://schemas.android.com/apk/res/android">' + [Environment]::NewLine + '    <uses-permission android:name="android.permission.INTERNET" />' + [Environment]::NewLine + '    <uses-permission android:name="android.permission.CAMERA" />')
}
if ($manifest -notmatch 'usesCleartextTraffic') {
  $manifest = $manifest.Replace('<application', '<application android:usesCleartextTraffic="true"')
}
Set-Content -Path $manifestPath -Value $manifest -Encoding utf8

flutter pub get
if ($LASTEXITCODE -ne 0) {
  throw "Nao foi possivel instalar as dependencias do aplicativo."
}

Write-Host ""
Write-Host "Aplicativo preparado com sucesso." -ForegroundColor Green
Write-Host "Ative a Depuracao USB no Galaxy Tab A9 e execute .\INICIAR_TABLET.ps1" -ForegroundColor White
