@echo off
rem Troca os contratos pelos niveis dos desastres: apaga os arquivos antigos dos contratos (pelo git, da para
rem recuperar no historico) e roda o pipeline do goat. Resultado em check-log.txt. Este arquivo se apaga no fim.
cd /d "%~dp0"
git rm -q src/shared/Logic/Contracts.luau src/shared/Config/ContractConfig.luau src/server/ContractService.luau src/client/Controllers/ContractsController.luau
echo Rodando o pipeline... (o resultado vai para check-log.txt)
lune run check fix > check-log.txt 2>&1
type check-log.txt
echo.
echo Pronto! Pode fechar esta janela.
pause
(goto) 2>nul & del "%~f0"
