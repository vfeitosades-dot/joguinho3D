# COSTA LIVRE 0.2 — Jogo original de cidade e praia

Projeto Godot 4.5.2 3D, Windows 64 bits. Original e inspirado no genero sandbox: **nao e GTA 5**, nem utiliza personagens, audio, texturas ou mapas protegidos do jogo.

## Conteudo
- Cidade modular costeira: centro, bairros, avenida e praia, predios comerciais, casas, rua, praca, calcadao e pier.
- Visual 3D Kenney CC0 com pontos de interesse artesanais (quiosque Brisa Cafe, posto de observacao, placas, bancos, iluminacao e letreiros).
- Personagem 3D em terceira pessoa, 7 tipos de carros dirigiveis, movimento de pedestres, dialogos e trafego com pontos de percurso.
- UI nova com menu, pausa, configuracao de qualidade, mapa ampliado, minimapa, velocimetro, avisos e objetivos.
- Campanha curta de exploracao em 5 etapas repetiveis, creditos, salvamento automatico no disco (user://costa_livre_save.json).
- Godot Compatibility para Intel HD 2500/4000. 800x450, 960x540 e 1280x720 (modo detalhado). Sem garantia de FPS.

## Controles
WASD/setas: caminhar ou dirigir. Shift: correr/acelerar. Espaco: pular/frear. Mouse: camera. E: entrar/sair de carro. F: conversar. M: abrir mapa. Esc: pausar. H: dicas.

## Uso local
1. Abra project.godot no Godot 4.5.2.
2. Antes, execute python tools/fetch_assets.py (baixa arquivos GLB Kenney CC0 de espelho publico usado pelo CI).
3. Aguarde a importacao de arquivos e pressione F5.
4. Para compilar no Windows via GitHub Actions, veja .github/workflows/costa-livre-windows.yml.

## Limites honestos
**Versao 0.2 prototipo:** nao contem historia longa, multiplayer, audio gravado, interiores completos, carros com fisica de simulacao nem NPCs com IA generativa. Modelos reutilizados sao de estilo low-poly e nao equivalem a um AAA; modelos muito realistas seriam excessivamente caros para a placa integrada. A compilacao valida editor e abertura headless, mas o executavel deve ser testado em Windows com a sua GPU.

Ver ASSETS_LICENSES.md.
