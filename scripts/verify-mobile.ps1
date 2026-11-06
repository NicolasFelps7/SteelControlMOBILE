$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)
flutter pub get
if ($LASTEXITCODE -ne 0) { throw "Falha em flutter pub get." }
flutter analyze --no-fatal-infos --no-fatal-warnings
if ($LASTEXITCODE -ne 0) { throw "Falha na analise do Flutter. Corrija antes de gerar o APK." }
flutter test
if ($LASTEXITCODE -ne 0) { throw "Falha nos testes." }
flutter build apk --release --dart-define=API_URL=https://web-production-6682df.up.railway.app
if ($LASTEXITCODE -ne 0) { throw "Falha no build Android." }
Write-Host "APK: build\app\outputs\flutter-apk\app-release.apk" -ForegroundColor Green
