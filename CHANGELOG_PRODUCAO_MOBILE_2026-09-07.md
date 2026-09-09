# Produção Mobile — 2026-09-07

- Corrigido layout que podia deixar a aba Produção em branco.
- Removido `Expanded` vertical em contexto de altura não limitada.
- Adicionados KPIs de produção, ciclos, carga elétrica e última leitura.
- Gráfico de produção com altura fixa e comportamento seguro em tablet/celular.
- Resumo produtivo e módulos por controlador.
- Histórico recente de telemetria.
- Estados explícitos para ausência/erro de telemetria.
- Nenhum dado de produção é inventado: a tela usa apenas `/maquinas/:id/telemetria` e os valores atuais da máquina.
