# SteelControl Mobile 1.11.3+22 — correção de sincronização de máquinas

- A Central de Máquinas usa exatamente `GET /maquinas`, o mesmo endpoint do Desktop.
- O app valida `GET /empresa/me` para confirmar que a sessão pertence à mesma empresa exibida no tablet.
- Respostas HTTP 401 na sincronização encerram a sessão local em vez de deixar a tela logada e vazia.
- Ao trocar o endereço do backend, a sessão é validada imediatamente no novo servidor.
- Quando a API retorna zero máquinas, a tela mostra um diagnóstico com servidor, empresa e quantidade devolvida pela API.
- Nenhuma regra de segurança, facial, IHM ou telemetria foi removida.
