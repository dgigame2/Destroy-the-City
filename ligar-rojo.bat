@echo off
rem Liga o Rojo para sincronizar o codigo com o Roblox Studio.
rem Lobby (lugar inicial, Destroy the City): este arquivo. No Studio: Plugins > Rojo > Connect (porta 34872).
rem Para a cidade (lugar Run), rode:  rojo serve run.project.json   (porta 34873)
cd /d "%~dp0"
echo Rojo ligado (LOBBY). Deixe esta janela aberta enquanto trabalha no Studio.
rojo serve default.project.json
pause
