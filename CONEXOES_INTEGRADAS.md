# SteelControl — máquinas de categorias livres e conexões pelo site

Esta atualização substitui o fluxo obrigatório do instalador. O site no Railway
pode manter uma conexão USB/serial JSON na própria aba do navegador do computador.
O mobile configura e acessa a mesma máquina por meio do backend. O programa
Windows não é necessário para esse fluxo. Integrações antigas via Edge continuam
opcionais para protocolos que exigem uma ponte própria.

## Atualização

1. Copie o conteúdo de `steelcontrol22desk-main` sobre o projeto desktop/backend
   existente e `SteelControlMOBILE-main` sobre o projeto Flutter existente.
   Este ZIP é cumulativo em relação ao pacote de conexões integradas anterior.
2. Suba o desktop/backend ao GitHub e aguarde o deploy saudável no Railway.
   A inicialização existente executa `prisma migrate deploy`. As migrações
   adicionam as tabelas de conexões e o campo de tipo de ponte; não limpam dados.
3. No projeto mobile, gere e instale o novo APK, versão 1.19.0+50:

   ```powershell
   flutter pub get
   flutter build apk --release --dart-define=API_URL=https://web-production-6682df.up.railway.app
   ```

4. Abra o site atualizado no Chrome ou Edge compatível do computador que tem
   acesso à porta serial. Use HTTPS e atualize a página com Ctrl+F5.
5. Entre como administrador. Em **Máquinas → Conexões**, clique em
   **Autorizar USB neste navegador** e selecione o dispositivo.
6. Cadastre a máquina como equipamento real. A categoria é texto livre:
   compressor, injetora, bomba, torno ou outra. O controlador pode ficar para
   depois; o cadastro usa o painel genérico quando não há um perfil específico.
7. No cartão, clique em **Conectar**, escolha a sessão de navegador, o protocolo
   **USB / serial JSON**, a porta autorizada e o baud rate informado pelo
   equipamento. Clique em **Salvar e conectar**.
8. Aguarde telemetria válida antes de considerar a conexão confirmada. A tela
   separa cadastro, monitoramento e controle. Abrir a porta não prova comunicação.
9. No mobile, entre na mesma empresa e abra o ícone de cabo no cartão. As mesmas
   portas autorizadas e configurações estarão disponíveis.

Mantenha o computador ligado, a conta autorizada e a aba **Máquinas** aberta.
Fechar, recarregar ou navegar para outra página encerra a ponte USB. Autorize a
porta novamente e salve a conexão para retomar. O botão **Encerrar USB** fecha as
portas e tenta revogar imediatamente a sessão no servidor. Quando a aba some sem
conseguir avisar o servidor, a presença expira por falta de sincronização.
Não há comunicação de hardware em segundo plano depois que o navegador fecha.
Não é necessário gerar um instalador novo para usar esta atualização pelo site.

## Contrato USB / serial implementado

O adaptador genérico recebe **um objeto JSON por linha**, terminado por `\n`.
Ele não detecta nem converte automaticamente protocolos binários proprietários,
G-code ou Modbus RTU. A máquina, controlador ou firmware deve fornecer o contrato
abaixo, ou um novo adaptador deve ser desenvolvido para o protocolo real.

Exemplo de telemetria recebida:

```json
{"temperatura":32,"corrente":1.4,"dadosExtras":{"pressaoBar":7,"rpm":1400}}
```

Campos específicos ficam em `dadosExtras`. Métricas ausentes não são inventadas
pelo adaptador. Para mensagens com outros nomes, use em **Configuração avançada**:

```json
{"fieldMap":{"temperatura":"sensores.temp","corrente":"motor.amperes"}}
```

O mapeamento lê caminhos de propriedades próprias e rejeita caminhos de protótipo.
O exemplo exige mensagens como `{"sensores":{"temp":32},"motor":{"amperes":1.4}}`.
Mensagens fora do contrato exibem falha de comunicação; elas não viram sucesso.

## Controle e confirmação

O padrão é monitoramento. Para controle, são necessários cargo permitido,
credencial de controle existente, controle remoto habilitado no cadastro,
liberação explícita da conexão e mapeamento de comandos do equipamento.
O navegador implementa o contrato de comandos genéricos da IHM. Comandos
específicos de robôs ou impressoras exigem seus adaptadores próprios.

Exemplo de mapeamento, somente se RUN e STOP forem os comandos reais do controlador:

```json
{"commandMap":{"IHM_START":"RUN","IHM_STOP":"STOP"}}
```

A máquina recebe JSON por linha com `id`, `comando` e `payload`. Ela precisa
responder, após executar e verificar o resultado:

```json
{"ack":{"id":123,"status":"CONCLUIDO"}}
```

O id deve corresponder ao recebido. Também é aceito `FALHOU`. Escrever na porta
não conclui um comando. ACK desconhecido é ignorado; ACK fora do prazo não vira
sucesso. Sem confirmação, o comando falha. Comandos reentregues não são executados
outra vez pelo navegador. START continua exigindo intertravamentos positivos
publicados pelo equipamento em `dadosExtras.hmi.interlocks` conforme a política
já existente. Desconectar ou enviar STOP não substitui emergência física.

## Categorias, protocolos e expansão

A categoria descreve o equipamento; o adaptador define como ele se comunica.
Qualquer categoria pode ser cadastrada. Monitoramento e controle dependem do
contrato real, do adaptador e das funções disponibilizadas pelo fabricante.
O catálogo na tela informa ambientes suportados e requisitos.

- Navegador, sem instalador: USB / serial JSON, com autorização do usuário.
- Pontes opcionais já existentes: Dobot, Modbus TCP/RTU, OPC UA, MQTT, HTTP/REST e
  TCP JSON. Esses drivers não passam a funcionar diretamente no navegador ou no
  Railway apenas por aparecerem no catálogo. Precisam de uma ponte com acesso à
  interface/rede industrial e configuração de registradores, tópicos ou nós.
- Equipamentos que já publicam na API SteelControl podem continuar usando os
  endpoints `/device/:id/telemetria` e a credencial específica da máquina.
- Sem interface de comunicação: são necessários sensores, controlador ou gateway
  externo; o cadastro continua disponível, mas o sistema não inventa telemetria.

Para adicionar um protocolo de navegador, implemente o contrato `open`, `command`
e `close` e registre a fábrica em `SteelControlAdapters.register`. A recepção usa
`onPacket`; falhas usam `onError`. Adicione o ambiente no catálogo do backend,
validação de parâmetros, autorização e testes antes de liberar a opção na tela.
Não carregue scripts arbitrários fornecidos por usuários como adaptadores.

## Autorização e dados

A sessão de navegador só nasce para um administrador autenticado, recebe a empresa
da sessão e expira em oito horas. O vínculo não usa CNPJ como credencial.
A ponte revalida cargo e empresa em cada sincronização. Se perder autorização ou
conectividade nessa verificação, fecha as portas e exige nova autorização.
Tokens e chaves ficam apenas na memória da aba, sem LocalStorage ou IndexedDB.
Como qualquer cliente web, o código da própria página pode acessar suas
credenciais em execução: não existe chave invisível para o dono do navegador.
O segredo de provisionamento é cifrado no banco e descartado após o ACK da ponte.
Cadastros, vínculos, configurações e revogações passam pela auditoria existente.

## Validação e pendências

Foram testados backend, catálogo de capacidades, validação de mapas, isolamento de
empresas, sessão expirada, captura de porta antes da rede, telemetria mapeada,
comando aguardando ACK físico, rejeição de ACK desconhecido, recusa de reentrega,
fechamento por troca de empresa e migrações com dados anteriores preservados.
As portas nos testes são simuladas; isso não comprova compatibilidade física com
todos os equipamentos. A tela web também foi exercitada em DOM simulado.

Não houve compilação Flutter ou teste com máquina/tablet físicos neste ambiente.
O SDK Flutter não está disponível aqui. A cópia mobile original recebida não
continha `lib/services/machine_service.dart`, referenciado pelo projeto: mantenha
esse arquivo do projeto que já compila no seu computador. O patch não o remove.
