# Atualização da demonstração

Ao salvar o nome da empresa, o backend atualiza seu sufixo e todos os logins
internos na mesma transação. Preserva o prefixo do funcionário e o e-mail real.
Se outra empresa já usar o nome, escolhe um sufixo único. Salve novamente o nome
atual para corrigir um sufixo antigo. Exemplo: joao@alfa.com vira joao@beta.com.
Esse identificador é um login interno; não cria uma caixa de e-mail.

Desktop e tablet consultam o sufixo atual ao abrir o cadastro; alterações
confirmadas são distribuídas pelo stream, conforme a conexão.

Depois da confirmação inicial do e-mail, as entradas com senha correta ou
facial inequívoca não pedem código toda vez. Permanecem códigos para o primeiro
contato não confirmado e para facial ambígua. Uma sessão sem código não é
identificada como MFA. Cargos, revogação, isolamento das empresas, chave Edge
e controle remoto habilitado continuam sendo exigidos nas operações aplicáveis.

A facial mobile aguarda duas análises frontais e a resposta do servidor.
A etapa atual só fica verde depois de concluída; sucesso só aparece após a API
confirmar. A API exige um rosto, movimento, posição frontal final e consistência
de identidade entre frames. É uma prova de movimento simples, não uma certificação
anti-spoofing equivalente ao Face ID de hardware. Teste a câmera e a iluminação
no tablet antes da apresentação. A queda do capacete agora dura 2,8 segundos,
com o impacto e as telas de boas-vindas sincronizados nos dois clientes.

## Publicar

Copie o conteúdo das pastas para cada projeto, substituindo os arquivos e
preservando .env/chaves privadas. Suba o desktop no GitHub e aguarde o deploy
Railway concluir. Depois gere o APK atualizado, na raiz do mobile:

```powershell
flutter clean
flutter pub get
flutter build apk --release --dart-define=API_URL=https://web-production-6682df.up.railway.app
```

Instale o novo app-release.apk no tablet. Não houve compilação Flutter nem teste
de câmera neste ambiente, que não tem o SDK.

## Limpar o banco para começar do zero

A limpeza não foi executada no seu Railway. Foi criado um comando administrativo
sem endpoint público. Ele exporta backup JSON de todas as tabelas de negócio e,
somente se o backup for salvo, apaga empresas, usuários, biometrias, máquinas,
telemetria e auditoria. Preserva as migrations e reinicia os identificadores.
O backup contém dados privados; não envie ao GitHub.

Na raiz do desktop, com as dependências instaladas e DATABASE_URL apontando
para o banco que deseja zerar:

```powershell
npm --prefix backend run demo:limpar -- --confirmar=APAGAR_TUDO_STEELCONTROL
```

O comando usa apenas o banco do ambiente em que é executado. Rodar com o .env
local não limpa o Railway. Para limpar o Railway, use a conexão externa desse
banco no seu computador ou outro ambiente administrativo autorizado. Nunca
envie a variável DATABASE_URL nem sua senha ao chat.
O backup fica em SteelControl-backups, na pasta do usuário que executou o comando.
Prefira rodar no computador: o disco de um contêiner Railway pode ser temporário.
Se houver SEED_ADMIN_EMAIL/SEED_ADMIN_PASSWORD no serviço, retire-as antes do
próximo reinício para evitar recriar automaticamente o administrador do seed.
Após limpar, saia no site/tablet e cadastre a empresa e os funcionários de novo.
Não use prisma migrate reset.
