# 1.14.0+41 — Dashboard industrial dinâmico

## 2026-09-28 — Painéis adaptativos por capacidade
- Dashboard comum de OEE, produção, segurança, manutenção, energia e conectividade.
- Seções adicionais configuráveis por máquina em `integracaoMeta.dashboard.sections`.
- Desktop e Mobile leem o mesmo contrato de telemetria em `dadosExtrasAtuais`.
- Ausência de sinal é exibida como “Não informado”, sem gerar telemetria fictícia.
- Painéis especializados do Dobot e da impressora 3D foram preservados.
- Indicadores avançados ficam recolhidos, ocultam categorias vazias e não repetem os cartões da visão geral.
- Estado aberto/fechado preservado durante atualizações e explicação de uso adicionada ao painel.
- Mobile hidrata o mesmo diagnóstico usado pelo Desktop e mescla pacotes parciais de telemetria, mantendo a contagem de sinais sincronizada.

# 1.13.0+40 — Biometric Command Center

## 2026-09-28 — Reconhecimento facial tecnológico
- Tela facial redesenhada como console biométrico industrial.
- HUD responsivo com câmera, rastreamento, prova de vida e processamento.
- Moldura de captura, contraste, profundidade e leitura de estado aprimorados.
- Pré-visualização isolada para reduzir repinturas da câmera.
- Autenticação, liveness, permissões e integração com o backend preservados.

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
# 1.12.10+39

- Reduz reconstruções globais do dashboard causadas por telemetria em alta frequência.
- Remove a placa laranja da navegação selecionada e preserva contraste no tema claro/escuro.
- Controle jog e ciclo automático consultam a pose sem remontar toda a aplicação.
- Polling de comandos Dobot mais leve e resposta manual mais rápida.
- Ação para redefinir os cinco pontos ensinados do ciclo automático.
