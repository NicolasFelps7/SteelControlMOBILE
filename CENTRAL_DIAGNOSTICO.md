> Fluxo atual de conexão e instalação: consulte `STEELCONTROL_EDGE_FLUXO.md`.

# Central de Diagnóstico — SteelControl

## Atualizar

Este pacote contém somente arquivos alterados, incluindo as atualizações de
conexões pelo navegador anteriores. Aplique cada pasta sobre o projeto
correspondente, preservando os outros arquivos do seu projeto.

1. Suba o projeto desktop/backend ao GitHub e aguarde o Railway concluir o deploy.
   O comando de produção existente executa as migrações Prisma. A nova migração
   inclui a Central de Diagnóstico e desativa somente os vínculos retirados do navegador.
   Não limpa contas, máquinas, funcionários ou histórico.
2. Atualize a página do site com Ctrl+F5.
3. Gere e instale o APK **1.21.0+52**, mantendo a assinatura usada no tablet:

   ```powershell
   flutter pub get
   flutter build apk --release --dart-define=API_URL=https://web-production-6682df.up.railway.app
   ```

O arquivo Kotlin MainActivity deve ser copiado também: ele abre o seletor nativo
para salvar CSV no Android. Não há dependência nova nem permissão ampla de acesso
a arquivos. O Edge deve ser atualizado para a versão 1.2.0; consulte STEELCONTROL_EDGE_FLUXO.md.

## Onde consultar

- Site: **Máquinas → Central de Diagnóstico**. Também há um botão na área de Logs
  do painel da máquina selecionada.
- Mobile: ícone de diagnóstico (lupa/ferramenta) na barra superior. Com uma máquina
  selecionada, a central começa filtrada por ela.
- Permissões: administrador, supervisor e técnico consultam os eventos operacionais.
  Registros administrativos de auditoria aparecem somente para administrador.
- A central permite filtrar máquina (inclusive arquivada), severidade, origem,
  período e texto: código, mensagem, nome da máquina ou usuário registrado.
- Cada consulta usa páginas de 50 eventos; o padrão é o último mês. O período
  máximo por consulta é de 366 dias. Clique em Aplicar filtros/Atualizar para
  atualizar os resultados.
- Exportar CSV utiliza os mesmos filtros e inclui até 5.000 eventos mais recentes.
  Se houver mais, a tela informa quantos ficaram de fora: reduza o período e
  exporte os demais. O relatório preserva as orientações de resolução.
- No Android, escolha o nome/local de gravação no seletor do próprio sistema.
  Cancelar o seletor não salva arquivo e não gera aviso de sucesso.

## O que é registrado

A central reúne quatro fontes do banco PostgreSQL:

1. `DiagnosticEvent`: transições de conexão e códigos de falha enviados pela ponte.
2. `Log`: eventos operacionais já existentes das máquinas.
3. `ComandoMaquina`: solicitação, última entrega e resultado com os horários
   disponíveis na tabela. Novos comandos humanos possuem referência ao usuário
   autenticado que os solicitou; comandos automáticos ou legados podem não ter
   usuário registrado. Os nomes não são inferidos de textos ou payloads arbitrários.
4. `AuditLog`: auditoria administrativa e tentativas negadas da empresa, para
   administradores. Respostas HTTP 500 ou superiores são identificadas como falhas
   do servidor, sem divulgar stack trace ou dados da requisição.

Etapas derivadas de tabelas antigas refletem os dados que já existiam. A central
não reconstrói erros locais perdidos nem os horários de todas as reentregas de um
comando antigo. Mensagens operacionais legadas não possuem severidade estruturada
original e aparecem como informação. Tentativas sem empresa identificada não são
atribuídas a uma empresa por suposição.

Telemetria continua em `TelemetryReading`, consultável pelo painel da máquina.
Ela não é repetida pacote a pacote na auditoria nem no CSV desta central.
Conexão e diagnóstico não recebem os valores de sensores como mensagens de log.

## Conexões e falhas

- O SteelControl Edge instalado envia os estados da conexão ao servidor. ONLINE
  depende de telemetria aceita; abrir um driver não comprova comunicação física.
- Transições são gravadas sem repetir um evento em cada heartbeat.
- O servidor verifica a presença a cada 15 segundos. Ausência de sincronização
  por 30 segundos, revogação ou expiração gera PONTE_OFFLINE. Isso informa perda
  de contato com a ponte, não falta de energia comprovada no equipamento.
- Estado e evento são transacionados. Comandos mantêm solicitação, entrega e
  resultado na tabela de comandos; o solicitante dos novos comandos humanos é
  vinculado ao usuário autenticado.
- A ponte Web Serial e sua fila de diagnóstico foram retiradas. Os eventos dela
  já recebidos permanecem no banco como histórico; mensagens locais antigas que
  nunca chegaram ao servidor não são recuperadas por esta atualização.
- Mensagens técnicas livres do driver não são copiadas para o relatório. A central
  usa estados e códigos seguros. Consulte o protocolo e o equipamento para falhas
  internas que ele não disponibiliza ao SteelControl.

## Guia rápido para o responsável da empresa

| Código | O que verificar |
| --- | --- |
| USB_PERMISSAO_NEGADA | Evento histórico da ponte retirada; use o SteelControl Edge instalado. |
| USB_INDISPONIVEL | Cabo, alimentação, baud rate e outro programa usando a mesma porta. |
| USB_DESCONECTADA | Reconectar o cabo, abrir o Edge e salvar a conexão novamente. |
| PACOTE_INVALIDO | Contrato JSON por linha e mapeamento; protocolo binário exige adaptador próprio. |
| PONTE_OFFLINE | Computador, internet e SteelControl Edge em execução. |
| SERVIDOR_INDISPONIVEL | Conectividade e disponibilidade da hospedagem/banco. |
| ACK_TIMEOUT | Conferir o estado físico antes de repetir qualquer movimento. |
| COMANDO_BLOQUEADO_LOCAL | Cargo, prazo, liberação remota, mapeamento e intertravamentos. |
| FALHA_SERVIDOR | Verificar disponibilidade e consultar o responsável pela hospedagem se persistir. |

Desconectar, fechar a aba ou enviar um comando de parada não substitui emergência
física. Nunca remova intertravamentos para tentar resolver uma falha de software.
Logs ajudam o responsável técnico, mas não eliminam a manutenção da máquina ou do
serviço. Defina responsáveis por hospedagem, cópias de segurança e capacidade do
banco antes de uso contínuo. Esta atualização não apaga registros automaticamente;
a política de retenção deve ser definida para a implantação da empresa.

## Privacidade e integridade

O coletor aceita somente códigos definidos no backend. Mensagens livres de drivers,
URLs com credenciais, tokens, chaves, vetores faciais e payloads de comandos não são
adicionados ao novo registro. A consulta da auditoria seleciona apenas campos
necessários, sem detalhes brutos. Logs legados passam por remoção de padrões comuns
de credenciais; isso não substitui revisar o conteúdo de mensagens legadas externas.
CSV escapa células e neutraliza prefixos de fórmula de planilha. O filtro de empresa
é aplicado no servidor a todas as fontes, inclusive na exportação. Não há endpoint
para excluir eventos pela central. Falhas observáveis não incluem defeitos internos
que o equipamento não informa nem perda de comunicação anterior à instalação.

## Verificação desta entrega

Testes de API, autorização, empresa, idempotência, 
transições, filtros, CSV e monitoramento de presença foram executados. SQL foi
exercitado em PostgreSQL embarcado com duas empresas e registros de todas as fontes.
A tela web foi exercitada em DOM simulado, incluindo texto com HTML malicioso.
Dart e Kotlin passaram pela análise sintática. A compilação Flutter/Android e o
seletor de arquivos ainda precisam ser validados no tablet: não há SDK Flutter
neste ambiente nem teste em máquina física. Preserve os serviços e telas existentes
na sua cópia local que não constavam no ZIP original, como machine_service.dart.
