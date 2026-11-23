# COSTA LIVRE — Godot 4.5.2 — Alpha 0.1

Pequeno jogo de exploração urbana 3D original, estilo *sandbox* costeiro. Não é GTA 5 e não é uma reprodução integral do jogo. Inclui cidade modular com prédios/comércio/casas, zona de praia e mar, calçadão, píer, carros dirigíveis e tráfego, pedestres com IA por estados, câmera de terceira pessoa e HUD.

**Meta de hardware:** i5 3ª geração, 8 GB RAM, Intel HD 2500/4000; Godot renderizador Compatibility; janela 960x540, sem pós-processamento caro, cidade com chunks carregados por proximidade. O FPS não foi medido nesse PC e não é garantido.

## Controles

| Tecla | Função |
| --- | --- |
| WASD ou setas | andar / dirigir |
| Shift | correr / acelerar |
| Espaço | pular / freio de mão |
| E | entrar e sair do carro próximo |
| F | conversar com pedestre próximo |
| Mouse | câmera livre |
| Roda | zoom |
| Esc | liberar/capturar cursor |
| H | mostrar ou ocultar dicas |

## Construir e rodar

1. Instale Godot 4.5.2.
2. Rode `python tools/fetch_assets.py` para obter os modelos CC0 GLB em `assets/kenney/`; se estiver offline, os substitutos procedurais ainda permitem que o jogo abra.
3. Abra `project.godot` no Godot, aguarde importação dos GLBs e inicie com F6/F5.
4. O workflow `.github/workflows/costa-livre-windows.yml` compila `COSTA_LIVRE.exe` para Windows e envia a um Release no GitHub quando os arquivos `COSTA_LIVRE_GODOT/` forem alterados.

## Limites desta versão

- Protótipo, não mundo AAA. O mapa cobre ~650m, mas renderiza prédios locais por setores.
- NPCs usam rotinas, pontos de passagem, pausas e detecção simples de veículos, não IA conversacional autônoma.
- Carros usam física arcade simples; não há tráfego inteligente de cidade inteira, interiores jogáveis, missões complexas, dublagem ou áudio.
- Sem violência, sem reprodução de conteúdo de GTA 5.
- **A versão Windows deve ser testada em um computador real após o build**. A execução e desempenho na Intel HD não puderam ser validados neste ambiente.

Modelos e licenças: [ASSETS_LICENSES.md](ASSETS_LICENSES.md).
