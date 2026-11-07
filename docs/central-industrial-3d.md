# SteelControl · Dashboard industrial 06.11-R6

Base desktop: 1a4324d (R4). Mobile: 1.26.1+60. Esta revisão corrige a organização visual e o escopo da auditoria.

## Estrutura do dashboard

O dashboard volta à disposição da versão original: cenário 3D ocupando toda a área principal, com cartões sobrepostos ao redor. O controle manual/automático permanece em janela central, e a manutenção mantém histórico, filtros e formulário organizado. Cabeçalho com logo, nome da máquina, usuário e Voltar para Máquinas preservados.

Os cartões continuam mostrando sensores próprios de cada família. No Dobot, J1–J4 e X/Y/Z/R ficam acima do braço; ferramenta e conexão ficam nos painéis laterais. A faixa inferior traz estado técnico e manutenção. Nos outros tipos, as seções se adaptam aos sensores do respectivo perfil. Não voltam cartões de produção, metas ou desperdício.

No desktop, o quadro usa as classes e a distribuição do painel original (op-board, op-results, op-belt, op-workflow e op-injection). O 3D não é limitado a uma coluna lateral. No tablet em paisagem, o mesmo princípio é usado com um Stack de cena e painéis. Em telas menores, os cartões se reorganizam abaixo da cena para permanecerem legíveis.

## Auditoria geral da empresa

A auditoria fica em um acesso geral na navegação, disponível sem escolher máquina. Não há botão de auditoria nos cartões nem aba de auditoria dentro da máquina.

A consulta usa /auditoria?limit=300, sem maquinaId. Reúne os eventos auditados da empresa, como acessos/contas, equipamentos e manutenção. Busca e filtro por ação atuam nos eventos carregados. A tela informa a quantidade carregada e não se apresenta como histórico integral.

O acesso continua restrito à administração. O backend mantém filtro por empresa da sessão. Geral significa toda a empresa autorizada, nunca todas as empresas do banco. O filtro de máquina antigo permanece no endpoint por compatibilidade, mas não é usado na nova interface. Os registros de auditoria anteriores não são removidos.

No Flutter, o acesso global do menu e o botão Auditoria geral abrem AuditScreen sem machineId. As abas da máquina ficam em dados técnicos, controle, manutenção, alertas e logs.

## Telemetria, controles e segurança

As fontes dos campos continuam em frontend/assets/machine-profiles.json e assets/machine-profiles.json no Flutter. Um campo sem medição válida mostra Sem dados. Os modelos são representações por família, não CAD calibrado ou validação de colisão.

As juntas usam amostras reais do controlador, com suavização de 120 ms entre leituras; posição-alvo não vira posição confirmada. Leituras antigas são sinalizadas. A frequência depende do USB, Edge e rede. O Edge já incluído na R4 publica também poses intermediárias em movimentos de Dobot.

Abrir o controle ou alternar Manual/Automático não inicia movimento. Fechar o executor local interrompe novas etapas e solicita parada pelo backend; um INICIAR confirmado depois do fechamento é cancelado. Continuam as permissões, limites, prazo de comandos e confirmação do Edge existentes. Parada por software depende de comunicação e não substitui a parada física.

## Atualização

1. Substitua o script antigo pelo ATUALIZAR_DASHBOARD_R6.ps1 desta revisão.
2. Execute no Windows e informe a cópia clonada steelcontrol22desk em main, sem alterações pendentes. O script faz pull --ff-only, aplica o patch, verifica arquivos/manifesto, cria commit e envia ao GitHub. Não usa reset ou force push.
3. Aguarde o Railway e abra /app/dashboard com Ctrl+F5. Confira 06.11-R6 no topo. Não há nova migration.
4. No mobile, extraia o ZIP em pasta nova, execute flutter pub get e scripts/verify-mobile.ps1; instale o APK gerado. O Railway não atualiza aplicativos já instalados. Android mínimo 24 com WebView/WebGL.

## Validação

247 testes backend aprovados, incluindo consulta geral com eventos de usuário e máquina, filtro obrigatório por empresa e restrição de cargo. Verificações DOM aprovadas: cenário inteiro, quatro painéis na disposição original, ângulos próximos ao braço, troca de equipamento, controle central, manutenção, logs e auditoria geral sem seleção de máquina. O teste de fechamento durante INICIAR continua aprovado sem enfileirar movimento.

Referências estáticas, manifesto e sintaxe/formatação Dart conferidos. O código Edge não mudou nesta revisão. Flutter/engine completo, APK, renderização gráfica no navegador/tablet e Dobot físico não foram testados neste ambiente. Consulte ENTREGA_EMPRESA.md para aceitação com os equipamentos da empresa.


## Ajuste visual pela referência enviada

A composição permanece a do dashboard industrial da referência: uma única cena 3D de fundo, cartões translúcidos laterais e inferiores, e juntas/posição acima do braço. Não há nova tela de painel lateral. As cores são laranja, grafite e aço do SteelControl. Botão de volta, logo, nome da máquina e usuário ficam no cabeçalho.

O cenário do dashboard ganhou racks, bancadas de roletes passivos, mesas, pallets e telas de proteção modelados em geometria 3D. São infraestrutura ilustrativa, sem ID de equipamento, rótulo de ativo, leituras, comandos ou animação de processo. Não representam a planta medida da empresa nem criam equipamentos no cadastro. Os robôs/máquinas selecionáveis continuam sendo os registros autorizados da API.

O enquadramento inicial do dashboard abre mais o campo de visão, para mostrar máquina e galpão juntos. O botão Focar seleção continua disponível para inspeção próxima. O modo é exclusivo do dashboard; a prévia de cadastro mantém seu comportamento anterior. Em Flutter, o mesmo motor local recebe somente o sinal factoryScene junto ao contrato visual já sanitizado.

O novo teste de infraestrutura 3D verifica geometria e matrizes finitas, ausência de IDs/juntas e descarte dos recursos. Os 247 testes backend e as verificações DOM passaram. Não foi feita validação gráfica em GPU/tablet ou compilação de APK neste ambiente.
