# BaseplateProject — versão Godot para Windows (4.4.1)

Este projeto Godot é uma **adaptação da lógica de `BaseplateProject.zip` (Unreal Engine 5.4, C++)**.

O ZIP original usa um C++ `ABaseplateCharacter` com câmera SpringArm de 4 m, movimento WASD ou setas, mouse para câmera, pulo com Espaço e Esc para sair. O arquivo original **não inclui o nível Baseplate.umap nem os assets de Manny**, que devem ser adicionados manualmente na Unreal. Por isso, o ZIP não pode ser empacotado como EXE da Unreal sem completar esses arquivos e instalar a Unreal Engine.

A versão Godot recria o chão cinza de 100 × 100 m, céu, luz e um **humanoide simplificado criado com formas 3D**. Não inclui os arquivos do Manny e não é um executável da Unreal.

## Controles
- **W A S D** ou **setas** — andar
- **Mouse** — girar a câmera em terceira pessoa
- **Espaço** — pular
- **Esc** — sair do jogo
- **Shift** — correr (extra)
- **R** — voltar ao ponto inicial (extra)

## Executar no editor
Abra `project.godot` na Godot 4.4.1 e pressione F5. Usa modo de compatibilidade GL para computadores simples.

## Download do .exe
No GitHub, abra **Actions** → **Godot Baseplate - Windows EXE** → execução concluída com sucesso → Artifacts → **Godot-Baseplate-Windows-EXE**. Extraia o ZIP e execute `BaseplateGodot.exe`.

O workflow compila com os templates oficiais da Godot; não exige licenciamento da Unity ou da Unreal. O .exe depende de a execução do workflow terminar com sucesso e ainda não foi testado em um PC Windows neste ambiente.

## Integração preparada para Manny original (branch manny-import-ready)

O personagem Manny verdadeiro **não está incluído**. Este repositório contém só o carregador opcional: ele busca `res://assets/manny/Manny.glb`, usa o modelo e as animações embutidas ao iniciar o jogo. Se o arquivo não estiver presente ou estiver sem animações, mantém o personagem geométrico anterior. **Nenhum EXE com Manny foi publicado.**

### O que falta para completar

1. Obter legalmente o modelo original em sua conta Epic/Fab: [Mannequins Asset Pack](https://www.fab.com/listings/ad542ee6-34d0-4828-a56c-13846cd649d0). É fornecido no formato Unreal Engine, não GLB pronto.
2. Confirmar os termos da **licença específica** para uso fora da Unreal. Por exemplo, alguns conteúdos Epic são rotulados *UE-Only* e não podem ser usados com a Godot. Não use assets UE-Only fora da Unreal.
3. Apenas se permitido, converter seu asset autorizado em um GLB contendo malha rigada, materiais, esqueleto e animações **Idle, Walk, Run, Jump** (opcional Fall). Salvar em `GODOT_BASEPLATE/assets/manny/Manny.glb` localmente.
4. Abrir a Godot, importar o arquivo e executar o jogo. Ajuste orientação/escala do GLB ao converter, se necessário. A cena deve conter um `AnimationPlayer` com esses clipes.
5. Gerar seu build localmente (Project > Export > Windows Desktop). O GitHub Actions do ramo público não inclui os assets locais, portanto não gerará o Manny apenas com o código atual.

**Atenção:** não faça upload do GLB original para um repositório público sem autorização de redistribuição. A licença padrão Fab permite incorporar assets a projetos, mas não compartilhar o asset bruto isoladamente; conteúdos *UE-Only* têm restrições adicionais. O pacote original exige acesso do titular à biblioteca Fab/Epic.
