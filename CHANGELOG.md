# 1.12.9+38 — estabilização SteelControl 1.0

## 2026-09-14 — IHM dedicada para impressora 3D
- Dashboard de impressora 3D redesenhado como IHM exclusiva e responsiva.
- O painel genérico deixa de aparecer quando o equipamento é uma impressora 3D.
- Suporte visual adaptativo para filamento, resina, SLS e integrações proprietárias.

- Corrige MIME real no multipart de imagens faciais (JPEG/PNG/WEBP).
- Cadastro de funcionário agora exige facial no mesmo fluxo; cancelamento/falha desativa automaticamente o cadastro criado.
- Corrige overflow em cards de máquinas, edição e diálogos de Device Key.
- Melhora responsividade de diálogos, teclado e ações em telas menores.
- Resolve automaticamente entre backend salvo, emulador Android (`10.0.2.2`) e tablet físico com ADB reverse (`127.0.0.1`).
- `--dart-define=API_URL=...` passa a ter prioridade sobre URL salva.
- GETs recebem uma nova tentativa curta em falhas transitórias de conexão.

# Changelog — SteelControl Mobile

## 1.12.8+37 — 2026-09-09

### Produto
- Dashboard dedicado ao Dobot Magician com telemetria, pose, articulações, efetuador e comandos supervisionados.
- Reconhecimento facial com liveness, múltiplos templates, tratamento de identidade ambígua e segundo fator por e-mail.
- Nome de facial no cadastro de funcionários, seguindo o fluxo do Desktop.
- Central de máquinas responsiva, sincronização realtime e fallback de atualização.
- Produção, manutenção, logs, alertas, auditoria, diagnósticos por controlador e multilíngue integrados ao backend SteelControl.

### Engenharia
- Estrutura do repositório organizada para entrega final: documentação em `docs/` e scripts em `scripts/`.
- Removidos arquivos temporários de patches e artefatos iOS gerados localmente.
- GitHub Actions atualizado para `actions/checkout@v5` e Flutter 3.47.2.
- CI mantém erros do analisador, testes e build APK como bloqueantes; avisos/informações de lint continuam visíveis sem derrubar o pipeline.

## Histórico
O histórico detalhado de implementação anterior foi consolidado nesta versão final para reduzir arquivos temporários e notas de patch na raiz do projeto.
