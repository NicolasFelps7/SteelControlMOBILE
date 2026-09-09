# SteelControl Mobile 1.12.7 — transição Nome da facial → câmera

- Corrige telas vermelhas rápidas ao confirmar o nome da facial antes da câmera.
- O `TextEditingController` do modal agora pertence ao ciclo de vida do próprio diálogo e só é descartado quando a rota termina.
- A abertura da câmera aguarda o fim do frame/animação de saída do diálogo.
- Evita sobreposição de rotas durante a transição.
- Liveness, múltiplos templates, anti-duplicidade e segundo fator não foram alterados.
