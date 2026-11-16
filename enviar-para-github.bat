@echo off
rem Envia o projeto para o GitHub: dgigame2/Destroy-the-City (branch carlos).
rem 1) salva tudo num commit (mensagem: o que estiver em mensagem-commit.txt, ou data e hora)
rem 2) envia para o GitHub. Na primeira vez junta com o README que o GitHub criou (o nosso vence se der conflito).
cd /d "%~dp0"
set REPO=https://github.com/dgigame2/Destroy-the-City.git
set BRANCH=carlos
where git >nul 2>nul
if errorlevel 1 (
  echo [ERRO] Git nao encontrado. Instale em https://git-scm.com/download/win e rode de novo.
  pause
  exit /b 1
)
git remote get-url destroy >nul 2>nul
if errorlevel 1 git remote add destroy %REPO%
git remote set-url destroy %REPO%
git checkout -q %BRANCH% 2>nul || git checkout -q -b %BRANCH%
git add -A
if exist mensagem-commit.txt (
  git commit -q -F mensagem-commit.txt
  del mensagem-commit.txt
) else (
  git commit -q -m "atualizacao %date% %time%"
)
echo Enviando para o GitHub (pode abrir uma janela de login)...
git push -u destroy %BRANCH%
if errorlevel 1 (
  echo Juntando com o que ja existe no GitHub...
  git pull -q --no-rebase --allow-unrelated-histories -X ours --no-edit destroy %BRANCH%
  git push -u destroy %BRANCH%
)
if errorlevel 1 (
  echo [ERRO] O envio falhou. Se apareceu 403, a conta logada nao tem permissao no repositorio.
) else (
  echo Pronto! Tudo enviado para github.com/dgigame2/Destroy-the-City ^(branch %BRANCH%^)
)
git log --oneline -3 > envio-log.txt 2>&1
git status -sb >> envio-log.txt 2>&1
pause
