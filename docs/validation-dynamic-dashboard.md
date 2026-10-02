# Validação da entrega 1.14.0+41

- integração do widget no dashboard principal verificada;
- balanceamento estrutural do arquivo Dart verificado;
- contrato compartilhado de telemetria documentado;
- painel preserva as IHMs dedicadas do Dobot e da impressora 3D.

Execute na máquina com o Flutter SDK:

```powershell
flutter pub get
flutter analyze
flutter test
flutter run --dart-define=API_URL=http://10.133.126.51:3000 --dart-define=ALLOW_INSECURE_HTTP=true
```
