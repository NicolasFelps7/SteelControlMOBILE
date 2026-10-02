# Dashboard industrial dinâmico

O aplicativo renderiza o mesmo painel adaptativo do Desktop. A telemetria vem exclusivamente de `dadosExtrasAtuais`; a definição de indicadores específicos vem de `integracaoMeta.dashboard.sections`.

Campos recomendados: `kpi.oee`, `kpi.availability`, `kpi.performance`, `kpi.quality`, `kpi.cycleTimeSec`, `quality.goodCount`, `quality.rejectCount`, `production.workOrder`, `production.batch`, `production.recipe`, `safety.estopOk`, `safety.doorClosed`, `safety.startPermit`, `maintenance.runtimeHours`, `maintenance.mtbfHours`, `maintenance.mttrMinutes`, `energy.powerKw`, `energy.totalKwh` e `utilities.airPressureBar`.

Exemplo de uma seção específica em `integracaoMeta`:

```json
{
  "dashboard": {
    "version": 1,
    "sections": [
      {
        "id": "hydraulic",
        "title": "Sistema hidráulico",
        "caption": "Pressão e temperatura do circuito principal.",
        "icon": "gauge",
        "metrics": [
          { "label": "Pressão principal", "path": "hydraulic.pressureBar", "unit": "bar", "icon": "gauge" },
          { "label": "Temperatura do óleo", "path": "hydraulic.oilTemperatureC", "unit": "°C", "icon": "temperature" }
        ]
      }
    ]
  }
}
```

Regras importantes:

- telemetria real tem prioridade sobre metadados do cadastro;
- percentuais aceitam `0..1` ou `0..100`;
- OEE é calculado quando disponibilidade, desempenho e qualidade existem;
- sinal ausente aparece como **Não informado**;
- categorias sem telemetria ficam ocultas e o painel avançado inicia recolhido;
- o snapshot de diagnóstico e os eventos em tempo real são mesclados para que Desktop e Mobile exibam os mesmos sinais;
- Dobot e impressora 3D mantêm suas IHMs especializadas;
- estados de segurança são supervisórios e não substituem dispositivos certificados.
