@echo off
rem Roda o pipeline do goat (Rojo build, testes, Selene, StyLua formatando) e salva tudo em check-log.txt.
cd /d "%~dp0"
echo Rodando o pipeline... (o resultado vai para check-log.txt)
lune run check fix > check-log.txt 2>&1
type check-log.txt
echo.
echo Pronto! Pode fechar esta janela.
pause
