# SteelControl Mobile

Versão 1.21.0+54: nova Central industrial. Veja [CENTRAL_INDUSTRIAL.md](CENTRAL_INDUSTRIAL.md) para publicação, fontes e uso no Galaxy Tab.

Atualização 1.20.1+53: veja [ATUALIZACAO_MOBILE_DESKTOP.md](ATUALIZACAO_MOBILE_DESKTOP.md) para as mudanças e os comandos atuais de execução.

Aplicativo Flutter do SteelControl para Android/iOS, integrado ao mesmo backend Node/Express, PostgreSQL/Prisma e Face API usados pelo Desktop.

## Principais recursos

- Login por e-mail/senha e reconhecimento facial.
- Liveness e templates faciais; em caso de ambiguidade, acesso por senha. Código de e-mail somente para concluir o cadastro.
- Gestão de empresa, funcionários e logo institucional.
- Máquinas, produção, manutenção, logs, alertas e auditoria.
- IHM industrial supervisionada e painel dedicado ao Dobot Magician.
- Telemetria realtime, diagnósticos por controlador e descoberta de equipamentos via backend.
- Tema claro/escuro e interface em seis idiomas.
- Layout adaptado para celular e tablets, incluindo Galaxy Tab A9.

## Estrutura

```text
android/            projeto Android
assets/             recursos visuais
docs/               documentação técnica
ios/                 projeto iOS
lib/                 código Flutter
scripts/             scripts de preparação/execução
test/                testes automatizados
tool/                ferramentas de validação
.github/workflows/   CI do aplicativo
```

## Preparar o projeto

Requisitos:

- Flutter 3.47.2 ou compatível
- Android Studio / Android SDK
- JDK compatível com o Flutter instalado

No PowerShell:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\scripts\setup.ps1
```

Ou manualmente:

```powershell
flutter clean
flutter pub get
flutter doctor -v
```

## Executar em tablet Android

Ative a Depuração USB e conecte o dispositivo. Depois:

```powershell
.\scripts\run-tablet.ps1
```

Para execução manual:

```powershell
flutter devices
flutter run -d ID_DO_DISPOSITIVO --dart-define="API_URL=http://IP_DO_PC:3000"
```

O Desktop/backend deve estar ligado e acessível pela rede local.

## Qualidade

Antes de enviar alterações:

```powershell
python tool/check_i18n.py
flutter analyze
flutter test
flutter build apk --debug
```

O GitHub Actions executa automaticamente integridade i18n, análise, testes e um build APK de fumaça.

## APK de apresentação

```powershell
flutter build apk --release --dart-define="API_URL=http://IP_DO_PC:3000"
```

Saída padrão:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## Segurança

- Tokens ficam no `flutter_secure_storage`.
- Senhas e imagens faciais não são persistidas pelo aplicativo.
- Permissões, autenticação, duplicidade facial e autorização de comandos são validadas no backend.
- Controle remoto de equipamento real permanece protegido pelas regras de segurança do SteelControl.
- Para ambientes fora de rede controlada, use HTTPS.

## Documentação

- [IHM industrial](docs/ihm.md)
- [Descoberta de equipamentos](docs/discovery.md)
- [Release mobile](docs/release.md)
- [Histórico de versões](CHANGELOG.md)
