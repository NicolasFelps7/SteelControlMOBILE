# Aceitação com a empresa

Revisão 06.11-R6. O painel usa dados técnicos e mantém controle e histórico por equipamento. A empresa deve conferir a versão instalada e os mapeamentos dos dispositivos antes de liberar uso operacional.

Concluído em testes de software: autenticação/permissões existentes, isolamento da auditoria geral por empresa, atualização de juntas, rejeição de leitura atrasada, funcionamento dos acessos de manutenção/logs/auditoria e tratamento de falha na publicação durante movimento.

Pendente no equipamento instalado:

- Comparar J1–J4 e X/Y/Z/R com o software local do Dobot; validar sinal/sentido de cada articulação e a ferramenta usada. Testar inicialmente sem carga, com supervisão local e área protegida.
- Conferir cada sensor e unidade com o controlador de cada máquina. Campos não mapeados devem continuar Sem dados. A representação visual por família não substitui CAD/calibração.
- Verificar perda de rede/USB, reconexão, expiração/cancelamento de comandos, revogação de sessão e comportamento de parada com o responsável pela máquina.
- Confirmar parada de emergência e intertravamentos físicos independentes da internet. A interface e o comando STOP por rede não são circuito de segurança.
- Compilar o APK, testar renderização e gestos no Galaxy Tab e conferir desempenho no PC da empresa.
- Registrar responsável, data, versões instaladas e resultado dos testes de aceitação, além da rotina de backup e restauração do banco.

Nenhum destes testes físicos foi realizado neste ambiente. Não há garantia de segurança absoluta, validação de colisão ou certificação de um nível de segurança funcional nesta entrega.
