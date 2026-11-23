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
