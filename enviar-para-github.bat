@echo off
rem Envia esta pasta para a branch main do GitHub (ic3chilling/jogo2).
rem Mantem o historico do main; arquivos do main que nao existem aqui sao removidos no commit,
rem exceto README.md e wally.toml (do Gabriel), que sao preservados.
cd /d "%~dp0"
where git >nul 2>nul
if errorlevel 1 (
  echo [ERRO] Git nao encontrado. Instale em https://git-scm.com/download/win e rode de novo.
  pause
  exit /b 1
)
if not exist .git (
  git init -b main
  git remote add origin https://github.com/ic3chilling/jogo2.git
)
echo Baixando o main atual do GitHub...
git fetch origin main
if errorlevel 1 (
  echo [ERRO] Nao consegui baixar do GitHub. Confira a internet e o acesso ao repositorio.
  pause
  exit /b 1
)
git checkout -q main 2>nul
git reset -q --soft origin/main
git checkout origin/main -- README.md wally.toml 2>nul
rem arquivos antigos do esqueleto (vazios) que nao fazem mais parte do jogo
del /q src\server\Main.server.luau src\client\Main.client.luau src\shared\Remotes\Names.luau src\shared\Logic\Economy.luau tests\Economy.spec.luau 2>nul
git add -A
git commit -m "Eat City: mapas maiores com litoral, areas por etapas, modos EASY/MEDIUM/HARD, feedback triplo, placas e setas das areas"
echo Enviando para o GitHub (pode abrir uma janela de login)...
git push origin main
if errorlevel 1 (
  echo [ERRO] O envio falhou. Se apareceu 403, sua conta nao tem permissao de escrita no repositorio.
) else (
  echo Pronto! Tudo enviado para o main.
)
pause
