# SteelControl Mobile

## Versão 1.8.0 — gestão, auditoria e controladores

- Logo da empresa pode ser alterada e removida diretamente em **Minha empresa** por administradores, usando os mesmos endpoints do desktop.
- Textos fixos restantes revisados para Português, English, Español, Français, Deutsch e Italiano, incluindo reconhecimento facial, diagnósticos, auditoria e recursos de controlador.
- Nova área administrativa de **Auditoria**, com pesquisa, filtros por ação/entidade/responsável, intervalo de datas, indicadores e histórico expansível.
- Diagnóstico específico por controlador (ESP32, Dobot Magician, CLP/PLC, CNC, controlador robótico, gateway industrial e genérico), com leitura do endpoint real de diagnóstico e fallback local.
- Recursos operacionais específicos de cada controlador ampliados na Visão geral e na Produção.
- Corrigido o `BOTTOM OVERFLOWED` do resumo produtivo no Galaxy Tab A9, com altura responsiva e chips compactos.

Versão 1.7.1: internacionalização integral da interface em Português, English, Español, Français, Deutsch e Italiano, incluindo login, cadastro, empresa, máquinas, dashboards, manutenção, validações, diálogos e mensagens locais. Uso seguro de contexto após operações assíncronas validado pelo analisador.

## Correção 1.6.3

- Ajustado o grid da Visão geral para usar um delegate compatível com `mainAxisExtent`.

## Correção 1.6.2

- Banner da central de equipamentos com o mesmo visual azul-preto do desktop nos temas claro e escuro.
- Cards da manutenção redimensionados para textos longos sem `BOTTOM OVERFLOW`.
- Grids de indicadores e formulários revisados para se adaptar com segurança a celular e tablet.

## Correção 1.6.1

- Removido o parâmetro obsoleto do gráfico de produção.
- Resolvido o conflito de `TextDirection` entre Flutter e `intl` apontado pelo analisador.

## Atualização 1.6.0

- Tela de Máquinas reorganizada com apresentação da frota, indicadores operacionais, pesquisa e filtros por tipo e status.
- Gráfico e resumo produtivo concentrados na seção Produção, sem duplicação na Visão geral e com layout seguro para tablets.
- Confirmação visual de acesso após login ou criação de conta, adaptada automaticamente aos temas claro e escuro.

## Versão 1.2 — acabamento visual profissional

### Correção 1.2.1

- atualização assíncrona segura da equipe após cadastrar ou demitir funcionário;
- remoção do erro vermelho `setState() callback argument returned a Future`;
- mesma proteção aplicada à atualização de registros no painel da máquina.

### Correção 1.2.2

- corrigida a recarga do histórico após registrar uma manutenção;
- removidas as referências inválidas a `_fetch` e `_data` no painel da máquina;
- a atualização agora usa o Future de manutenção pertencente à própria tela.

- design system azul-marinho consistente nos temas claro e escuro;
- cards com hierarquia, bordas e sombras discretas;
- correção do `BOTTOM OVERFLOWED` nos equipamentos;
- formulário industrial de máquina dividido em identificação, operação e comunicação;
- painel de preferências redesenhado para tema e idioma;
- boas-vindas compacta, segura e alinhada à identidade SteelControl;
- equipe com cargos, biometria e conta atual apresentados em badges;
- componentes responsivos para tablet e celular.

## Versão 1.1 — paridade com o desktop

- reconhecimento facial automático com interface empresarial;
- cadastro facial único por perfil e remoção de biometria;
- cadastro, edição e demissão de funcionários;
- edição de nome, e-mail, senha e cargo, com código para troca do próprio e-mail;
- localização completa e CNPJ formatado;
- cadastro, edição, remoção e regeneração de chave de máquinas;
- seleção visível nos temas claro e escuro;
- configurações simplificadas para tema e idioma, sem painel de conexão exposto.

Aplicativo Flutter para Android criado a partir do SteelControl Desktop. Ele não possui banco paralelo: login, reconhecimento facial, empresa, usuários, logo, máquinas, telemetria, produção, manutenção, logs, alertas e comandos Dobot usam a mesma API Node/Express e o mesmo PostgreSQL/Prisma do desktop.

## Experiência no Galaxy Tab A9

- Layout responsivo em modo retrato e paisagem.
- No tablet, a navegação fica em uma barra lateral profissional.
- Cada máquina abre um painel próprio; o Dobot recebe painel e comandos especializados.
- Tema claro e escuro usam a mesma identidade azul-marinho do desktop.
- A marca SteelControl permanece na navegação. A logo do cliente aparece somente em **Minha empresa**.
- A sessão é guardada no armazenamento seguro do Android.
- A autenticação facial usa a câmera frontal, análise de qualidade e prova de vida antes do login.

## 1. Preparar o computador

Instale:

1. Flutter estável: <https://docs.flutter.dev/get-started/install/windows/mobile>
2. Android Studio, Android SDK e Platform Tools.
3. No terminal, confirme com `flutter doctor`.

No PowerShell, dentro desta pasta, execute:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\PREPARAR_APP.ps1
```

Esse script gera os arquivos nativos compatíveis com a versão do Flutter instalada e baixa as dependências.

## 2. Ligar o backend do desktop

No projeto Desktop, execute normalmente `INICIAR_STEELCONTROL.ps1`. O backend já escuta em `0.0.0.0:3000`, permitindo que o tablet acesse a API pela rede local.

Descubra o IP do computador:

```powershell
ipconfig
```

Copie o **Endereço IPv4** do adaptador Wi-Fi, por exemplo `192.168.0.10`. Computador e tablet devem estar na mesma rede Wi-Fi. Se o Windows perguntar, autorize o Node.js em redes privadas. A porta TCP 3000 também precisa estar liberada no Firewall.

## 3. Conectar o Galaxy Tab A9

1. No tablet, abra **Configurações > Sobre o tablet > Informações do software**.
2. Toque sete vezes em **Número da versão** para ativar as Opções do desenvolvedor.
3. Ative **Depuração USB**.
4. Conecte o tablet por USB e aceite a chave RSA mostrada na tela.
5. No PowerShell do aplicativo, execute:

```powershell
.\INICIAR_TABLET.ps1
```

Informe o IPv4 do computador quando solicitado. O Flutter instalará e abrirá o aplicativo no tablet.

## 4. Ajustar a conexão pelo próprio aplicativo

Na tela de login, toque na engrenagem e informe:

```text
http://IP-DO-COMPUTADOR:3000
```

O endereço técnico não aparece na interface do cliente. No emulador, o app usa `10.0.2.2:3000`; no tablet físico, o script `INICIAR_TABLET.ps1` solicita o IPv4 do computador antes de abrir o aplicativo.

## 5. Gerar APK para a apresentação

Com o endereço da escola definido, rode:

```powershell
flutter build apk --release --dart-define="API_URL=http://192.168.0.10:3000"
```

O APK ficará em:

```text
build\app\outputs\flutter-apk\app-release.apk
```

Se o IP da escola mudar, não é necessário recompilar: abra a engrenagem do login e salve o novo endereço.

## Testes

```powershell
flutter analyze
flutter test
```

Os testes verificam a compatibilidade dos modelos de sessão, empresa e máquinas com as respostas do backend do TCC.

## Cadastro profissional de equipamentos

A versão 1.3.0 leva para o tablet o mesmo fluxo organizado do desktop:

- quatro dados essenciais visíveis de início;
- modelo pronto para braço robótico;
- detalhes, rede e limites em seções expansíveis;
- seleção entre simulação e equipamento real;
- controlador, protocolo e configuração segura do Dobot Magician;
- limites operacionais validados antes do envio;
- equipamento real permanece offline até receber telemetria verdadeira.

## Gestão, manutenção e acessibilidade visual

A versão 1.4.0 adiciona:

- manutenção profissional no padrão do desktop, com resumo, histórico, cadastro e exclusão administrativa;
- correção do ciclo de vida do diálogo de manutenção e da árvore de idioma/navegação;
- Logs visíveis e acessíveis somente para administradores;
- edição dos dados institucionais da empresa pelo aplicativo;
- atalho de gerenciamento da empresa dentro de Configurações;
- logo SteelControl clara e legível no tema escuro;
- tradução ampliada para login, navegação, máquinas, produção, manutenção, logs, alertas e configurações.

## Produção e telemetria por controlador

A versão 1.5.0 aproxima os painéis mobile da experiência do desktop:

- prévia de produção dentro da visão geral de todas as máquinas;
- tela produtiva completa com gráfico de barras, resumo, ciclos, status, pico, média e última leitura;
- perfis próprios para ESP32, Dobot, CLP/PLC, CNC, controlador robótico, gateway e equipamentos genéricos;
- qualidade de sinal e latência interpretadas diretamente da telemetria do backend;
- estado offline não gera histórico fictício e continua identificado visualmente;
- textos principais da nova área disponíveis nos seis idiomas do aplicativo.

## Observações de segurança

- O token de acesso é armazenado com `flutter_secure_storage`.
- Senhas e imagens faciais não são gravadas pelo aplicativo.
- A API continua responsável por permissões, identidade facial única, ambiguidade e acesso à empresa correta.
- Em produção fora da rede escolar, troque HTTP por HTTPS.
