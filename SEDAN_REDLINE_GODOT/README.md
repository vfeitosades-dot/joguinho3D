# REDLINE — VORTEX S4

Jogo de demonstração automotiva 3D feito em **Godot 4.5** para Windows, com **uma única baseplate** e um sedã esportivo vermelho criado por geometria procedural, peça por peça. Inspirado em uma referência visual fornecida separadamente no pacote ZIP (o modelo 3D é uma interpretação e não uma reprodução perfeita).

## O que já está implementado

- Modelo 3D do sedã com carroceria facetada, pintura PBR metálica, acabamento clearcoat, grades, faróis de LED, lanternas, retrovisores e para-choques;
- Interior com bancos, painel, telas, console e volante;
- Vidros transparentes com reflexos de ambiente (skybox) e guarnições;
- Rodas com pneus, aros, raios, cubos, disco de freio, porcas e sulcos;
- Portas, capô, porta-malas, rodas e direção com animações calculadas pelo jogo;
- Câmera orbital, controle de distância, baseplate e iluminação de estúdio;
- Minijogo **ficcional** de "ligação direta": sincronize três pulsos de um painel digital. Não usa conexões de fiação reais;
- Condução simples estilo arcade, velocímetro, faróis e sons sintéticos de partida, motor e interface, gerados durante a execução.

## Controles

| Tecla | Ação |
| --- | --- |
| E | Entrar no carro / sair (abre o minijogo ao entrar pela primeira vez) |
| Espaço | Sincronizar um pulso durante o minijogo |
| W/A/S/D ou setas | Dirigir e virar depois de ligar o motor |
| Q | Abrir/fechar porta dianteira esquerda |
| H | Abrir/fechar o capô |
| T | Abrir/fechar porta-malas |
| L | Alternar os faróis |
| R | Reposicionar o carro |
| Mouse, botão esquerdo segurado | Girar câmera |
| Scroll do mouse | Zoom |

## Rodar no Godot

1. Baixe e extraia este projeto ZIP.
2. Abra o Godot **4.5.2** (ou outra versão compatível de Godot 4.x).
3. Clique em `Importar`, selecione `project.godot` e abra o projeto.
4. Pressione **F6/F5** para iniciar.

## Exportar um EXE

No Godot, selecione `Projeto > Exportar > Windows Desktop`, instale os modelos de exportação, se necessário, e clique em `Exportar projeto`. A configuração `export_presets.cfg` já está incluída. Para linha de comando:

```bash
godot --headless --path . --editor --quit
godot --headless --path . --export-release "Windows Desktop" build/REDLINE.exe
```

`REDLINE.exe` precisa ser gerado pelo Godot, com os modelos de exportação instalados. **O código-fonte ZIP não é o executável.**

## Build no GitHub Actions

O workflow `.github/workflows/redline-windows.yml` do projeto pode gerar um artefato para Windows. Ele também verifica a importação do projeto; depois publica `REDLINE-Windows` como artefato do workflow, se terminar com sucesso. Para usá-lo em um repositório que armazene este projeto numa subpasta, a configuração de `path` deve apontar para essa pasta.

## Detalhes técnicos

A geometria e os sons são construídos ao iniciar o jogo por `scripts/car_factory.gd`. A lógica do jogo e as animações são controladas por `scripts/game.gd`. A interface do minijogo ficcional usa `scripts/hotwire_ui.gd`.

Sem modelos externos, sem pacotes pagos e sem personagens ou mapas adicionais. Projeto demonstrativo; física automotiva simplificada, sem promessa de fidelidade fotográfica ou equivalência mecânica a um jogo AAA.
