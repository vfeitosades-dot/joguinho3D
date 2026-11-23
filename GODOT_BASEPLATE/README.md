# Baseplate 3D — Godot 4.4.1

Recriação em Godot do **baseplate simples** feito anteriormente como conceito na Unreal Engine: piso cinza de 100 × 100 m, iluminação diurna, humanoide de formas geométricas e câmera em terceira pessoa.

**Importante:** não se trata de exportação direta da Unreal. O projeto Unreal anterior era um gerador de cena, sem um mapa `.umap` compilado. Os elementos aqui foram refeitos diretamente na Godot, sem reutilizar assets da Epic.

## Controles
- W A S D — andar
- Shift — correr
- Espaço — pular
- Botão direito do mouse (segurar e mover) — orbitar a câmera
- R — voltar ao início

## Executar no editor
Abra `project.godot` com Godot 4.4.1 e pressione F5. Compatibilidade GL em vez de Forward+, pensada para hardware mais simples.

## Baixar o executável Windows no GitHub
1. No repositório `vfeitosades-dot/joguinho3D`, abra **Actions**.
2. Selecione **Godot Baseplate - Windows EXE**.
3. Abra a execução bem-sucedida mais recente ou execute manualmente com **Run workflow**.
4. Em **Artifacts**, baixe **Godot-Baseplate-Windows-EXE**.
5. Extraia o ZIP e abra `BaseplateGodot.exe` no Windows.

O build usa Godot e templates oficiais via GitHub Actions, sem licença ou senha. O `.exe` só estará disponível após um job concluído com sucesso.

## Exportar manualmente
Na Godot, menu **Project → Export → Windows Desktop → Export Project** e salve como `BaseplateGodot.exe`.
