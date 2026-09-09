# SteelControl Mobile 1.11.5 — lista direta de máquinas

- Central de Máquinas usa `GET /maquinas` como fonte principal.
- Remove dependência de `/maquinas/sync` para compatibilidade com o Desktop atualmente instalado.
- Falha não crítica em `/empresa/me` não apaga nem bloqueia a lista já carregada.
- `401` continua sendo tratado como sessão inválida.
- Nenhuma regra de segurança, telemetria, IHM ou facial foi alterada.
