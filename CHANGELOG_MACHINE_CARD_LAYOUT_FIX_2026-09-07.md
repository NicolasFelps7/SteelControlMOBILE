# SteelControl Mobile 1.11.7+26 — correção de renderização da grade

- Remove `Spacer()` vertical do card de máquina, evitando flex em altura não limitada dentro de `SectionCard`.
- Preserva o grid de máquinas e a mesma API `GET /maquinas`.
- Ajusta `Material` da sidebar para não usar fundo transparente nos `ListTile`, eliminando warnings de ink/splash invisível.
- Nenhuma regra de backend, autenticação, telemetria ou segurança foi alterada.
