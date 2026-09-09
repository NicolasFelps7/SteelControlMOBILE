# SteelControl Mobile — Facial Liveness Timeout

Versão: 1.12.3+32

- Prova de vida do login/cadastro inicial agora oferece até 8 segundos para detectar movimento de cabeça.
- Durante o período, a câmera realiza novas verificações automáticas de pose (yaw) em vez de depender de uma única captura fixa.
- Movimento aceito: `abs(yaw) >= 10`, preservando a regra já usada pelo fluxo anterior.
- Se o movimento não for detectado no tempo limite durante o login, a captura é encerrada, uma mensagem orienta a refazer o reconhecimento e a tela facial é fechada.
- No cadastro inicial, o fluxo permanece na etapa facial para permitir nova tentativa sem perder os dados/código de verificação já informados.
- Arquivos temporários de capturas rejeitadas continuam sendo removidos.
- Novos textos do timeout foram adicionados aos 6 idiomas do aplicativo.

Nenhuma alteração foi feita no backend, Face API, InsightFace, PostgreSQL, threshold de identidade ou regras de segurança do servidor.
