# Ajustes Mobile — 2026-09-04

- Removida a configuração visível de **Servidor SteelControl** das Configurações e do modal da tela de login. A infraestrutura de conexão permanece interna e compatível com `API_URL`/configuração já persistida.
- Cadastro facial alterado para **validar/capturar primeiro e pedir o nome depois da câmera**. Cancelar o nome não salva biometria.
- Cadastro inicial da empresa mantém o fluxo atômico: empresa/login só são persistidos após facial validada + nome confirmado.
- Login em tablet deitado recebeu modo compacto por altura útil, além de detecção do teclado, scroll robusto e ocultação do painel azul/branding quando necessário, eliminando o `Bottom Overflowed`.
- Nenhuma regra de segurança facial, liveness, autenticação ou sessão foi relaxada.
