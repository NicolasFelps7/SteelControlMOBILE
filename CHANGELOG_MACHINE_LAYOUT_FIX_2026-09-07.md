# SteelControl Mobile 1.11.6+25 — correção da Central de Máquinas

- Remove listener duplicado do `MachinesScreen` que chamava `setState` durante notificações globais do `AppController`.
- `loadMachines()` deixa de reconstruir o `MaterialApp` inteiro por padrão; a Central de Máquinas atualiza localmente após a resposta da API.
- Mantidos realtime, polling de fallback e filtros.
- Ajustados `ListTile` da sidebar para um `Material` explícito, eliminando avisos de ink/background em builds recentes do Flutter.
- Nenhuma alteração de backend, contrato de API, facial ou regras de segurança.
