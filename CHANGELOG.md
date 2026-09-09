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
