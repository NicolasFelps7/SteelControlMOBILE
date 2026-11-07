# SteelControl · Central industrial

Implementação web/API + Flutter 1.21.0+54, baseada no desktop `3dc6dad` e no mobile sem fotografia no login.

## Acesso e atualização

1. Execute `ATUALIZAR_DASHBOARD_INDUSTRIAL.ps1` no Windows, informando a pasta clonada `steelcontrol22desk`. O script exige branch main e pasta sem alterações pendentes, faz pull sem reescrever histórico, aplica os arquivos, verifica referências/manifesto, cria commit e envia ao GitHub.
2. Aguarde o deploy do Railway ficar Active. O Docker existente gera o Prisma Client e aplica a migration `20261106120000_industrial_operation_records` antes de iniciar. A migration adiciona somente a tabela de registros e seus índices/relações; não remove máquinas nem altera dados de autenticação.
3. Abra `/app/dashboard` ou `/app/operacao`. Clique em um equipamento no cenário ou use o seletor. Os cartões de equipamentos abrem a nova visão. **Painel técnico** abre os controles e diagnósticos anteriores por controlador.
4. No mobile, extraia o ZIP atualizado em uma pasta nova, abra a pasta que contém `pubspec.yaml`, execute `flutter pub get` e depois `flutter build apk --release`. Instale `build/app/outputs/flutter-apk/app-release.apk` no Galaxy Tab. O deploy do site não atualiza APKs já instalados.

Para backend local, depois de atualizar o código, execute na pasta `backend`: `npm ci`, `npx prisma generate`, `npx prisma migrate deploy`. Aplique migrations somente no banco correspondente ao ambiente configurado em `DATABASE_URL`. Não use reset ou migrate dev em produção.

## Painel

- Fundo industrial em perspectiva, grafite/laranja, com resultados à direita, esteiras à esquerda, workflow inferior e indicadores de injetoras.
- Filtros de 24 horas, 7 dias e 31 dias (janelas móveis), máquina e fonte dos indicadores.
- Produtos fabricados, tempo por unidade, desperdício, ciclos observados, tempo produzindo/parado/em manutenção, unidades/hora e atingimento da meta.
- Workflow de pedidos, fabricação, embalagem, notas fiscais e distribuição.
- Atualização ao retornar ao app e consulta a cada 15 segundos em primeiro plano; eventos da empresa notificam alterações de cadastro/registros. O backend mantém cache de até 3 segundos. Suspensão, internet indisponível e múltiplas réplicas podem adiar a atualização.
- Mesma API, catálogo de 59 mensagens em seis idiomas e mesmo cenário no web e no Flutter. Tablet em paisagem usa painéis sobrepostos; telas estreitas reorganizam os painéis em coluna.
- Clique no cenário seleciona um equipamento e filtra os dados. Até oito atalhos aparecem no cenário; o seletor permite escolher os demais. A consulta geral limita a 100 equipamentos e sinaliza quando o escopo deve ser reduzido.
- O cenário é uma ilustração 3D estática, com seleção interativa sobreposta. Não é uma planta medida da empresa, nem reproduz a posição física ou o movimento do braço. Os estados dos equipamentos e indicadores são dados separados, provenientes da API.
- O login do mobile permanece sem fotografia. O cenário aparece somente no novo dashboard.

## Fonte 1: telemetria

Não são gerados valores demonstrativos no código de produção. Um traço acompanhado de “Sem dados” significa ausência de medição confirmada, e não zero. Máquinas em simulação não alimentam os indicadores reais.

A API interpreta contadores acumulados enviados em `dadosExtras.operacao.contadores` nas leituras reais. Exemplo de contrato (os números devem vir do processo):

```json
{
  "dadosExtras": {
    "operacao": {
      "contadores": {
        "fabricados": 150,
        "rejeitados": 3,
        "ciclos": 160,
        "pedidos": 170,
        "embalagem": 145,
        "notasFiscais": 30,
        "distribuicao": 140,
        "producaoSegundos": 3600,
        "paradaSegundos": 120,
        "manutencaoSegundos": 60,
        "metaUnidades": 180
      }
    }
  }
}
```

Esse bloco acompanha a telemetria já autenticada do equipamento/Edge. Não foi criado um acesso de dispositivo sem credencial. As contagens são inteiras; tempos são em segundos. Os contadores representam totais acumulados; o painel calcula deltas dentro da janela, usa a última amostra anterior como base e trata redução como reinício. Sem base anterior, a parcela desconhecida é sinalizada; não se extrapola produção que não foi observada.

O campo legado `producao` só é interpretado como quantidade fabricada em equipamentos fora do perfil Dobot quando o cadastro contém `integracaoMeta.operacao.producaoConfirmada=true`. Use isso apenas quando a origem desse contador tiver sido verificada. `ciclos` exige `ciclosConfirmados=true`, contador explícito ou perfil Dobot. Isso evita transformar defaults do banco em medições.

No gateway Dobot atual, `producao` aumenta por movimento PTP concluído. Por isso ele não é usado automaticamente como produto fabricado. Os ciclos continuam disponíveis como movimentos observados; para peças acabadas, envie o contador explícito do processo ou use registros de turno.

Esteiras são identificadas por nome/tipo/controlador contendo “esteira” ou “conveyor”; injetoras por “injet” ou “inject”. Cadastre os equipamentos com identificação correspondente.

## Fonte 2: registros de turno

Administradores, supervisores e técnicos podem registrar totais reais de um turno para uma máquina fora de simulação. Visitantes e operadores consultam os indicadores, mas não gravam registros.

- Preencha data/hora, equipamento e apenas os indicadores conhecidos. Campos vazios permanecem desconhecidos; zero deve ser digitado quando confirmado.
- Cada registro contém incrementos daquele turno, não o total acumulado desde o início da máquina. A meta é a quantidade planejada para aquele registro.
- Preencha os campos relacionados no mesmo registro para calcular percentuais/tempos. Não se calcula desperdício juntando fabricados de um turno com rejeitados de outro turno incompleto.
- Reenvios do mesmo formulário conservam o identificador e não duplicam o lançamento. Alterar os valores inicia um novo identificador. Reabrir o formulário representa um novo lançamento; confira os registros recentes antes de lançar o mesmo turno novamente.
- A remoção é lógica, aparece na auditoria e retira o registro dos totais. O identificador removido não pode ser reaproveitado para recriar um lançamento.
- Telemetria e registros de turno são fontes separadas; não são somados entre si para evitar dupla contagem.
- Pedidos/notas fiscais/distribuição são contagens informadas pelo processo ou pelo responsável. O painel não emite nota fiscal, não altera pedidos de um ERP e não simula uma integração de faturamento inexistente. Registre cada evento de negócio uma única vez.

## Cálculos

- Tempo por unidade = segundos produzindo / produtos fabricados.
- Desperdício = rejeitados / (fabricados + rejeitados) × 100.
- Unidades/hora = fabricados / segundos produzindo × 3600.
- Meta atingida = fabricados / meta do período × 100; pode ultrapassar 100%.
- As razões só aparecem quando os campos necessários estão presentes em fontes compatíveis. Campos parciais não são preenchidos artificialmente.

## Segurança e limites

As rotas `/empresa/operacao` passam pela autenticação existente, rechecagem de sessão/empresa e proteção de origem para cookies. O banco filtra por empresa e máquinas ativas. Escritas verificam cargo e propriedade do equipamento, rejeitam dados inválidos, possuem limite de tentativas e chave de idempotência por empresa. A consulta histórica usa SQL parametrizado, limite de consultas por usuário e prazo de 8 segundos no banco. Registros nunca enviam comandos ao robô.

Os comandos e as proteções do Edge permanecem nos painéis técnicos existentes. O cenário não aciona equipamentos quando selecionado. A supervisão do processo não substitui os sistemas físicos de segurança.

## Validação e limites do ambiente

Verificados: schema Prisma e geração do client, migration aditiva em PostgreSQL via PGlite, leitura de contadores explícitos/legados confirmados, janela e reinícios, isolamento entre empresas, cargos, idempotência, registros removidos, campos parciais, rotas HTTP reais (dashboard novo/painel técnico/API sem sessão), referências estáticas e manifesto.

Os testes do backend e os testes específicos de operação foram executados no Node disponível neste ambiente; o projeto/Docker continua configurado para Node 22. Testes Flutter de responsividade foram adicionados, mas não executados: não há Flutter/engine completo aqui. A tentativa de prévia automatizada do navegador foi bloqueada pelo ambiente (Chromium sem acesso ao socket de perfil; navegador remoto sem acesso ao localhost). Não foi compilado APK nem realizado teste no Galaxy Tab ou com hardware nesta entrega. Execute `scripts/verify-mobile.ps1` no Windows e confira o painel no dispositivo antes da apresentação.

## Cenário visual

Arquivo integrado: `frontend/assets/img/operation-floor.png` no desktop e `assets/images/operation-floor.png` no Flutter. Criado com a ferramenta integrada de geração de imagens, a partir da referência enviada; sem logotipo, textos ou números incorporados. Os cartões e valores são componentes do sistema.

Prompt final do cenário: “Factory digital twin background only, elevated wide three-quarter industrial perspective, robotic arms along roller conveyors, packages, circular assembly stations, safety fences, cabinets and racks; SteelControl amber/orange housings, graphite chassis, brushed steel, muted dark interior; realistic professional CAD visualization; landscape 16:10, low-contrast background for UI overlay; no text, numbers, logos or floating panels.”
