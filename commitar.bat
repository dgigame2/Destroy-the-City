@echo off
cd /d "%~dp0"
if not exist mensagem-commit.txt (echo Falta o arquivo mensagem-commit.txt & pause & exit /b 1)
git add -A
git commit -F mensagem-commit.txt
if errorlevel 1 (pause & exit /b 1)
del mensagem-commit.txt
git log --oneline -1
pause
