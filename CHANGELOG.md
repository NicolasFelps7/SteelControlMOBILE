# 1.17.0+46 — Paridade visual Mobile/Desktop

## 2026-10-09 — Facial, login, máquinas e dashboard dinâmico
- Facial em tablet retrato usa o console biométrico completo, como no Desktop.
- Login concluído exibe o mascote industrial com o capacete encaixando antes de abrir o painel.
- Remove o monograma `SC` da cena do login e preserva uma identidade industrial mais limpa.
- Lista de máquinas aparece antes das áreas de cadastro manual e descoberta automática.
- Dashboard dinâmico permanece visível quando configurado, inclusive antes da chegada da telemetria, exibindo `Não informado` como no Desktop.
- Contagem do painel diferencia sinais ativos e indicadores configurados.

# 1.16.2+45 — Teste realtime compatível

## 2026-10-09 — Correção final do `flutter analyze`
- Atualiza `realtime_sync_test.dart` para a API atual de `SessionEventService`.
- Remove o uso obsoleto do parâmetro `sseClientFactory`.
- Mantém a validação de inicialização e encerramento seguro do realtime sem abrir conexão durante o teste.

# 1.15.0+42 — Dashboard por perfil de máquina

## 2026-10-02 — Cadastro inteligente e sincronizado
- Escolha do tipo da máquina recomenda os módulos adequados no cadastro manual.
- Seleção ajustável de OEE, produção, segurança, manutenção e energia.
- Mesma configuração `integracaoMeta.dashboard` no Desktop e no Mobile.
- O painel aparece apenas quando habilitado e com sinais reais nos módulos escolhidos.
- Dobot, impressora 3D, IHM e regras de comando permanecem inalterados.

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
# 1.16.0

- identidade visual mobile alinhada ao Desktop nas cores preto, branco e laranja;
- nova animação industrial leve no acesso para tablets, sem WebGL ou dependência externa;
- transições suaves entre Máquinas, Empresa, Auditoria e dashboards;
- dashboard dinâmico reorganizado como telemetria complementar;
- aliases de sinais resolvidos recursivamente para manter os mesmos indicadores do Desktop;
- configuração do dashboard preservada quando o Edge envia atualizações parciais;
- qualidade de sinal e latência adicionadas aos indicadores avançados;
- estado aberto do dashboard preservado durante atualizações em tempo real.

# 1.16.1+44 — Compatibilidade e análise limpa

## 2026-10-09 — Correções do Flutter Analyze
- Importa explicitamente o construtor de transição Cupertino usado no tema.
- Mantém a cor clara do destaque industrial disponível ao dashboard dinâmico.
- Remove importação redundante e aplica chaves no fluxo condicional.
- Nenhuma regra de comando, segurança, Edge ou telemetria foi alterada.

