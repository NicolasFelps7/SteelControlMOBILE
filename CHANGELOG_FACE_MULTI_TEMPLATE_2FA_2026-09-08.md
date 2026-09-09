# SteelControl Mobile — Facial Multi-Template + 2FA

Data: 2026-09-08
Versão: 1.12.4+33

- Enrollment envia três capturas ao backend: frontal inicial, movimento/liveness e frontal final.
- Mantém timeout de 8 segundos para prova de vida.
- Login trata `FACE_AMBIGUOUS` sem escolher identidade automaticamente.
- Em caso ambíguo, abre confirmação adicional por e-mail + código de 6 dígitos.
- O app não recebe nomes/e-mails dos candidatos; envia o e-mail informado pelo próprio usuário ao backend.
- Sessão só é aceita após confirmação do código pelo backend.
- Compatível com perfis antigos de um template; o formato multi-template é controlado pelo backend compartilhado.
