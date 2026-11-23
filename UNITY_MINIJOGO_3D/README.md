# Bloco Quest — Minijogo 3D para Unity

Minijogo original e leve em terceira pessoa. **É um projeto-fonte Unity, não um .exe já compilado.**

## O que tem
- Piso 3D quadriculado, blocos, cinco estrelas coletáveis e iluminação
- Personagem humanoide feito de formas 3D, com animação simples dos braços e pernas
- WASD para andar, Shift para correr, Espaço para pular
- Mouse com botão direito pressionado para girar a câmera
- R para reiniciar, Esc para liberar o cursor
- Interface com placar, instruções e aviso de vitória
- Sem assets externos e sem downloads de modelos

## Abrir no Unity
1. Instale o Unity Hub e **Unity 2022.3.62f1** (LTS), com suporte a Windows Build.
2. Abra no Unity Hub esta pasta `UNITY_MINIJOGO_3D` (a pasta que contém Assets, Packages e ProjectSettings).
3. Na primeira importação, um script do Editor gera `Assets/Scenes/BlocoQuest.unity` automaticamente.
4. Abra a cena criada (se necessário) e pressione Play.

Também existe o menu do editor **Bloco Quest > Criar / Recriar cena**.

## Gerar o .exe pelo Unity
No Editor: **Bloco Quest > Gerar EXE para Windows**. O gerador cria um jogo Windows 64 bits na pasta `build/StandaloneWindows64` do repositório. Distribua o `.exe` **junto** da pasta `BlocoQuest_Data` e dos demais arquivos produzidos pelo build.

## Gerar .exe pelo GitHub Actions
O workflow `.github/workflows/unity-bloco-quest-windows.yml` fornece build Windows e envia os arquivos como artefato ZIP. Unity exige licença para compilar no CI.

- Nas configurações do repositório: Settings > Secrets and variables > Actions, crie os secrets **UNITY_LICENSE**, **UNITY_EMAIL** e **UNITY_PASSWORD**, usando sua própria licença Unity. **Nunca publique os valores nos arquivos do repositório ou nos comentários.**
- Em Actions, execute **Unity — Bloco Quest Windows EXE** por **Run workflow**.
- Quando a execução terminar com sucesso, abra o job e baixe o artefato `BlocoQuest-Windows64`. O ZIP inclui o EXE e os arquivos de dados indispensáveis.

Guia de ativação: https://game.ci/docs/github/activation/
Guia do compilador: https://game.ci/docs/github/builder/

A compilação real ainda não foi executada nem testada, portanto não há executável pronto neste repositório.
