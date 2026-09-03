# IHM / Controle Industrial — SteelControl Mobile

A versão 1.9.0 adiciona ao aplicativo Flutter a mesma IHM supervisionada do Desktop para controladores ESP32, CLP/PLC, controlador robótico, CNC, gateway industrial e controlador genérico. O Dobot Magician continua usando seu painel dedicado.

## Como testar em simulação

1. Inicie o backend do SteelControl Desktop que contém a rota segura da IHM.
2. No app, cadastre ou edite uma máquina e selecione um controlador diferente de Dobot.
3. Mantenha **Simulação** selecionada.
4. Abra a máquina pelo botão **Abrir IHM / Controle**.
5. Use AUTO/MANUAL, START, STOP, RESET e ACK. Em simulação, nenhuma ação é enviada a hardware físico.

## Equipamento real

O controle remoto real continua opt-in. Na edição da máquina, selecione **Equipamento real** e habilite **Habilitar comandos remotos no equipamento real** somente depois de configurar Device Key, telemetria `dadosExtras.hmi` e intertravamentos físicos.

A interface não libera START apenas por estar online. O backend continua sendo a autoridade e exige cargo autorizado, telemetria recente, conexão estável e `interlocks.startPermitted=true`, além de bloquear condições inseguras.

## Segurança

- Comandos são enviados somente para `/maquinas/:id/ihm/comandos`.
- O app não contorna permissões do backend.
- START real pede confirmação adicional no aplicativo.
- STOP fica disponível aos cargos autorizados como parada operacional.
- RESET não é apresentado como liberação de parada de segurança.
- O app exibe o motivo de bloqueio retornado pela política de START.
- O STOP da IHM não substitui E-stop físico, relé de segurança, Safety PLC, contatores, cortina de luz ou qualquer dispositivo exigido pelo projeto da máquina.

## Backend compatível

Use o SteelControl Desktop com a IHM supervisionada instalada. Sem a rota `/maquinas/:id/ihm/comandos`, a tela continuará mostrando diagnóstico, porém os comandos não poderão ser processados.

## Descoberta de equipamentos e fallback por IP

Antes de abrir a IHM, o app pode localizar equipamentos compatíveis pelo backend. Se a busca automática não retornar nenhum dispositivo, use **Fallback por IP** e informe o IPv4 local do controlador/gateway. O app também exibe um diagnóstico de rede para ajudar a diferenciar listener UDP indisponível, ausência de interface IPv4 privada, falta de resposta ao broadcast, múltiplos adaptadores/VPN e falha na tentativa por IP.

A descoberta nunca habilita START; após aprovação, `remoteControlEnabled` continua falso até liberação administrativa explícita.
