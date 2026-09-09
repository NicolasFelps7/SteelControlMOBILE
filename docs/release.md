# SteelControl Mobile — release

## Qualidade
Execute:

```bash
python tool/check_i18n.py
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

O GitHub Actions executa estes passos automaticamente.

## APK de produção
O projeto aceita `android/key.properties` com um keystore privado. Copie `android/key.properties.example`, ajuste os valores e mantenha o arquivo real fora do Git.

Sem `key.properties`, o build release mantém fallback de assinatura debug apenas para testes/apresentação local. Não publique esse APK em produção.

## Rede
HTTP em rede local permanece permitido para a banca/emulador. Uma implantação comercial deve usar HTTPS e revisar a política Android de cleartext.

## Realtime
- Sessão remota: `/auth/session-events`.
- Empresa: `/empresa/stream`.
- Máquina selecionada: `/maquinas/:id/stream`.

O backend continua sendo a fonte final de verdade e revalida usuário, empresa, cargo e versão da sessão.
