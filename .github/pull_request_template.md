## SteelControl — checklist de mudança

- [ ] Não incluí `.env`, senhas, tokens ou chaves reais.
- [ ] Rodei `npm run quality`.
- [ ] Rodei `.\VALIDAR_PROJETO.ps1` no Windows quando aplicável.
- [ ] Se alterei comportamento industrial, executei o E2E completo.
- [ ] Se alterei arquivos funcionais congelados, atualizei o freeze de forma consciente e documentada.
- [ ] A mudança mantém compatibilidade com PostgreSQL, Face API e gateways industriais.
