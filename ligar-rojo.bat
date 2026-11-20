@echo off
rem Liga o Rojo para sincronizar o codigo com o Roblox Studio. No Studio: Plugins > Rojo > Connect (porta 34874).
cd /d "%~dp0"
echo Rojo ligado (Disaster Evolution). Deixe esta janela aberta enquanto trabalha no Studio.
rojo serve default.project.json
pause
