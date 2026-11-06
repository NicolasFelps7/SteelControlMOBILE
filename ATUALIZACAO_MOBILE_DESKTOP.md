# SteelControl Mobile 1.20.1+53

Atualização baseada no mobile enviado e no desktop `163545e`.

## Mudanças

- Login sem fotografia e sem globo no celular e tablet. Formulário centralizado, marca, tema e idiomas preservados. A fotografia industrial fica somente no site/desktop.
- Textos novos em português, inglês, espanhol, francês, alemão e italiano; tema claro/escuro mantido.
- Login de contas já verificadas não solicita código recorrente. O código permanece para concluir cadastros pendentes, conforme a API atual. Reconhecimento facial ambíguo exige senha; o fluxo antigo de código por e-mail foi removido do mobile.
- Railway HTTPS como servidor padrão. O endereço provisório antigo é migrado. Servidores personalizados são preservados e a troca exige novo login; tokens não são enviados ao novo servidor nem através de redirecionamentos HTTP.
- Sincronização de máquinas ativa em todas as telas autenticadas, com eventos da empresa, reconexão, atualização ao voltar ao app e consulta de recuperação a cada 5 segundos em primeiro plano. Exclusões recebidas removem imediatamente o item e fecham o painel selecionado. Uma resposta antiga não restaura IDs excluídos.
- Sem exibição automática nem cópia de chave para o Edge ao cadastrar máquina. A configuração usa o aplicativo SteelControl Edge do PC, na mesma empresa. O mobile não procura o USB no próprio celular.
- Computadores de navegador antigos são desconsiderados. A seleção de porta é limpa quando o PC/porta desaparece; salvar exige PC online e porta válida para protocolos seriais explícitos.
- HOME remoto removido; a calibração é local supervisionada. Limites numéricos do Dobot são conferidos também no mobile. Velocidade PTP limitada a 60%, conforme a API. Comandos POST não são repetidos automaticamente.
- Sair também solicita revogação ao servidor. Sem rede, o acesso local é removido e aparece um aviso de que a revogação remota não pôde ser confirmada.

## Como usar no Windows

1. Extraia este ZIP em uma pasta nova. Mantenha sua cópia anterior como backup. Não copie `build`, `.dart_tool`, chaves de assinatura ou configurações privadas de outra instalação.
2. Abra a pasta que contém `pubspec.yaml` no VS Code. Use Flutter 3.47.2 ou versão compatível com o lockfile (Flutter >=3.44 / Dart >=3.12), Android SDK e JDK compatível.
3. Conecte o Android por USB, habilite a depuração USB e autorize o PC no dispositivo.
4. No PowerShell, na raiz do projeto:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-tablet.ps1
```

Para escolher um dispositivo: acrescente `-DeviceId "ID_EXIBIDO_EM_FLUTTER_DEVICES"`.

Para verificar e gerar o APK:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-mobile.ps1
```

O APK será criado em `build\app\outputs\flutter-apk\app-release.apk`. A assinatura de produção continua dependendo da configuração privada do responsável pelo projeto. Não foi gerado um APK neste pacote.

## Edge / Dobot

Abra o SteelControl Edge no PC fisicamente ligado ao braço, faça login na mesma empresa e vincule o computador. No mobile, cadastre como **Equipamento real**, escolha **Dobot Magician (USB)**, selecione o PC online e a porta enumerada pelo Edge. COM1 só deve ser usada se for efetivamente a porta do Dobot. Se não houver porta, confira alimentação, cabo e driver no PC.

Site, mobile e Edge precisam usar o mesmo backend e a mesma empresa. A alteração deve aparecer assim que o evento chegar pela rede. Durante desconexão ou suspensão do Android, a sincronização ocorre ao reconectar/retomar; não há garantia de latência zero. O mobile precisa ser recompilado e instalado para receber alterações de código: o deploy do Railway atualiza a API/site, não um APK já instalado.

## Validação realizada

- Executado `scripts/check-sync.dart`: exclusão com snapshot atrasado, isolamento entre sessões, reutilização de código com novo ID, valores não finitos, envelope de movimento, velocidade e HOME remoto.
- Catálogo compilado em Dart: 713 mensagens com seis traduções preenchidas, sem chaves duplicadas; 582 referências de texto verificadas.
- Formatação e parsing Dart dos arquivos alterados concluídos.
- Testes Flutter de layout atualizados para conferir ausência de imagem e presença dos dois campos em celular, tablet e paisagem. Mantidos os testes de idiomas, servidor, redirecionamento, comandos sem repetição e erros de autorização. **Não executados aqui:** o ambiente não possui Flutter/engine completo. Execute o script de verificação no PC antes de publicar.
- Não houve execução em hardware, pentest ou publicação no Git deste mobile. Nenhuma proteção física ou certificação de segurança é substituída pelo aplicativo.
