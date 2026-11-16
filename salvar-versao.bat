@echo off
rem Salva uma versao do projeto no git (so local, nao envia para o GitHub).
cd /d "%~dp0"
git add -A
git commit -m "desastres, cadeia e contratos (antes da vida/escombros)"
echo.
git log --oneline -3
echo.
echo Pronto! Pode fechar esta janela.
pause
