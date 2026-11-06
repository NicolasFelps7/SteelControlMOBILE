# SteelControl Edge — fluxo após o cadastro

## O que mudou

A comunicação com hardware volta a ser feita pelo SteelControl Edge instalado no
computador. A ponte USB/Web Serial da página foi retirada. O site mantém o cadastro,
a gestão, o controle autorizado e a Central de Diagnóstico. O mobile usa o mesmo
Edge vinculado à empresa. Não é necessário manter a aba do site aberta.

A janela do Edge usa o tema, cores e tipografia do SteelControl, apresenta a empresa
autenticada, lista as máquinas reais e oferece configuração, atualização e diagnóstico.
O cadastro não é repetido no Edge: ele recebe apenas o ID da máquina já criada.

## Atualizar os três componentes

1. Copie os arquivos de `steelcontrol22desk-main` sobre o projeto desktop/backend
   e os de `SteelControlMOBILE-main` sobre o projeto Flutter. O pacote é cumulativo
   em relação às alterações de conexões e diagnóstico anteriores.
2. Suba o desktop/backend ao GitHub. Aguarde o deploy do Railway ficar saudável.
   A inicialização existente executa as migrações. A nova migração desativa somente
   vínculos do tipo NAVEGADOR e revoga as chaves associadas a esses vínculos. Ela
   preserva contas, funcionários, máquinas, logs, auditoria e vínculos do Edge.
3. Gere o instalador **1.2.0** usando o workflow já existente:
   GitHub → Actions → Gerar instalador SteelControl Desktop → Run workflow.
   Baixe o artefato SteelControl-Instalador-Windows e extraia o executável.
4. Encerre a versão antiga pelo ícone próximo ao relógio, usando Sair. Instale a
   atualização no mesmo usuário Windows. Abra o programa uma vez para registrar
   a abertura por link. O instalador antigo 1.0/1.1 não possui o novo fluxo completo.
5. No mobile, gere o APK **1.21.0+52** e instale sobre o aplicativo atual, com a
   mesma assinatura:

   ```powershell
   flutter pub get
   flutter build apk --release --dart-define=API_URL=https://web-production-6682df.up.railway.app
   ```

6. Atualize a página do site com Ctrl+F5.

Não limpe o banco. Preserve os outros arquivos do seu projeto; esta entrega contém
somente arquivos alterados. A cópia mobile original não continha alguns serviços
referenciados, como machine_service.dart: mantenha a versão que já compila localmente.

## Cadastrar e conectar pelo site

1. Entre como administrador e cadastre a máquina em **Equipamento real**.
2. Ao terminar, o site solicita a abertura do SteelControl Edge com o ID da máquina.
   O link não carrega senha, token, Device Key ou endereço de servidor.
3. Se o navegador bloquear a abertura automática ou pedir autorização, clique em
   **Abrir SteelControl Edge** no diálogo. Não há confirmação falsa de que o app
   abriu: o sistema aguarda telemetria antes de confirmar a conexão física.
4. No primeiro acesso ao Edge, faça login na mesma empresa. Depois do login, a
   máquina é retomada automaticamente. Confira o nome da empresa na janela.
5. O Edge autoriza seu vínculo com a empresa e carrega as portas do computador.
   Se ainda estiver detectando as portas, aguarde a atualização ou clique em
   Atualizar estado. Um Edge já vinculado a outra empresa não é transferido
   silenciosamente: o responsável deve revogar o vínculo anterior.
6. Confira o protocolo, porta USB/serial ou IP, baud rate e parâmetros do fabricante.
   Clique em **Salvar e conectar**. A nova credencial é provisionada internamente
   ao Edge e protegida com DPAPI no Windows, sem precisar copiá-la manualmente.
7. Aguarde **Comunicação confirmada**. Salvar uma configuração ou abrir uma porta
   não comprova comunicação com o equipamento.

O botão **Conectar no Edge** permite repetir o fluxo em máquinas existentes.
**Configurar um Edge já vinculado** mantém uma alternativa de gestão remota pela
página, sem assumir que o computador da máquina seja o mesmo do navegador.
Máquinas simuladas funcionam dentro do sistema e não abrem um driver físico.

## Cadastro pelo mobile

Depois do cadastro real, o app abre a etapa **Conexão pelo Edge**. Se um Edge já
estiver vinculado e online, selecione-o e envie a configuração por essa tela.
Caso contrário, abra o Edge no computador da máquina, entre na mesma empresa,
escolha o cadastro na lista e configure a conexão. O cadastro feito no tablet já
está no sistema; não crie uma segunda máquina no computador.

O tablet não consegue abrir um programa Windows em outro computador. Uma vez
configurado, site e mobile acompanham e operam a mesma máquina pelas permissões
existentes. A autorização para configurar conexões continua restrita ao administrador.

## Execução e manutenção

- O computador, o Edge, o acesso à máquina e a conexão com o servidor precisam
  permanecer disponíveis. Fechar a janela mantém o programa próximo ao relógio.
- O menu Sistema → Iniciar com o Windows controla a execução ao entrar no usuário
  Windows. Não é um serviço que funciona antes do login do Windows.
- **Sair e desconectar máquinas** encerra o programa. Desconectar não substitui a
  parada de emergência física nem interrompe necessariamente um movimento já iniciado.
- A Central de Diagnóstico continua no site e no mobile; também há um botão na
  janela do Edge. Transições e resultados de comandos permanecem no PostgreSQL.
- Vínculos manuais da janela antiga ficam preservados no arquivo local, mas o
  fluxo integrado usa configurações autorizadas pelo sistema. Reconfigure pelo
  cadastro correspondente se ainda usava o pacote de chave manual da versão 1.0.

## Protocolos e confirmação

O catálogo inclui Dobot, serial JSON, Modbus TCP/RTU, OPC UA, MQTT, HTTP/REST e TCP
JSON. Cada máquina exige interface e protocolo compatíveis. Categoria livre não
significa que o fabricante dispense um adaptador, mapa de registradores, tópicos,
nós ou driver USB do Windows. A aplicação não identifica todos esses contratos
apenas pelo nome da máquina.

No adaptador **serial JSON**, envie um objeto por linha terminado por `\n`.
Campos adicionais são mantidos em dadosExtras. Exemplos de configuração avançada:

```json
{"fieldMap":{"temperatura":"sensores.temp"},"commandMap":{"IHM_START":"RUN","IHM_STOP":"STOP"},"ackTimeout":5}
```

Para comandos, o equipamento recebe `id`, `comando` e `payload`. Deve responder
somente depois de verificar o resultado:

```json
{"ack":{"id":123,"status":"CONCLUIDO"}}
```

Também pode responder FALHOU. O ID precisa corresponder ao recebido. Sem ACK, o
comando falha; a gravação na porta não significa execução confirmada. Firmware
serial antigo que não envia ACK precisa ser adaptado antes de habilitar comandos.
O monitoramento não exige habilitar comandos. Os demais protocolos mantêm suas
confirmações específicas; um ACK de transporte não certifica o resultado mecânico.

O Edge guarda resultados recentes para não repetir um movimento depois de perda
do ACK HTTP. Reentregas de movimento sem resultado local conhecido são recusadas.
STOPs continuam seguindo a política existente. Cargo, credencial de controle,
controle remoto e intertravamentos continuam obrigatórios conforme o comando.

## Validação

Foram executados testes de backend, aplicativo e motor Python, incluindo links
inválidos, ausência de credenciais no link, instância única, retomada após login,
autorização do frame principal, vínculo, configuração, ACK serial, telemetria e
proteção contra reexecução. A migração foi executada em PostgreSQL embarcado com
vínculos nativos e de navegador, contas e histórico. A interface foi exercitada
em DOM simulado, com texto malicioso tratado como texto.

Ainda é necessário gerar e testar o instalador Windows 1.2 e o APK nos dispositivos.
Não houve compilação Windows/Flutter nem homologação em equipamento físico aqui.
