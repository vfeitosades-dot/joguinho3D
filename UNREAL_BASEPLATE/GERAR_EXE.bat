@echo off
setlocal
cd /d "%~dp0"
echo Unreal Engine 5 - Baseplate e personagem padrao
if not "%~1"=="" (
  set "UPROJECT=%~1"
) else (
  set /p "UPROJECT=Arraste aqui o arquivo .uproject Third Person e pressione Enter: "
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0gerar_exe.ps1" -ProjetoThirdPerson "%UPROJECT%"
if errorlevel 1 (
  echo A geracao nao foi concluida. Verifique os erros.
)
pause
