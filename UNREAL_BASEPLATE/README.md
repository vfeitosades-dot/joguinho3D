# Unreal Engine 5 — Baseplate + personagem padrão

Este diretório contém um **gerador de projeto e de build para Windows**, não um jogo compilado.

## Requisitos
- Windows 10/11
- Unreal Engine 5 instalada pelo Epic Games Launcher
- Um projeto criado no template oficial **Games > Third Person > Blueprint > Variant None**

## Como usar
1. Crie o projeto Third Person oficial e feche a Unreal.
2. Baixe os arquivos deste diretório.
3. Arraste o arquivo `.uproject` criado por você sobre `GERAR_EXE.bat`.
4. O gerador copia o projeto para `ProjetoBaseplate`, cria o piso e tenta exportar a versão Windows em `JogoWindows`.
5. Se compilar, distribua a pasta de saída **inteira** (não só o .exe).

O personagem, as animações e a câmera são os arquivos originais do Third Person template e não estão incluídos aqui. Isso evita redistribuir binários/assets da Epic. O procedimento não foi testado com uma instalação real da Unreal neste ambiente; versões diferentes podem precisar de ajustes.

**Não há .exe publicado neste repositório.** Para gerá-lo é necessária uma instalação funcional da Unreal Engine 5 com ferramentas de build para Windows.
