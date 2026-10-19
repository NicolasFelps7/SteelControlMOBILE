# Cadastro, login interno e autorização e-CNPJ

Atualize primeiro o backend e aplique as migrations, inclusive
`20261019190000_autorizacao_ecnpj`.

O novo cadastro confirma e-mail/biometria e abre a tela de autorização e-CNPJ.
O responsável salva o arquivo original, assina com ferramenta de sua confiança
em CMS/CAdES destacado (.p7s, DER, SHA-256 ou superior) e seleciona a assinatura
para envio. PFX/P12, chaves privadas e senhas não devem ser enviados.

O backend exige cadeia confiável, LCRs vigentes e CNPJ correspondente à conta
nomeada. Sem a configuração real de confiança, o cadastro continua bloqueado.
Não há mais aprovação manual por comando. Leia AUTORIZACAO_ECNPJ.md no desktop.

Contas pendentes podem retomar a etapa após login e confirmação do código de
e-mail. Após validar a empresa, volte ao login para obter a sessão operacional.
Somente o administrador cadastra funcionários na Gestão Industrial. O login
interno usa a parte digitada pelo administrador e o sufixo fixo da empresa,
com e-mail real separado para os códigos de acesso.

Execute `flutter pub get` (nova dependência `file_picker` 8.3.7), `flutter analyze`,
`flutter test` e a compilação no seu computador. Flutter não estava disponível
no ambiente de edição; o APK não foi compilado nesta entrega.
