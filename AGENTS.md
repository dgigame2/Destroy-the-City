# Disaster Evolution — instruções para o agente (Codex / Claude)

Jogo Roblox: o jogador é um **tornado** que destrói a cidade, sobe de nível, faz rebirth e luta PvP.
Responda em português, simples e direto.

## Leia primeiro
- Status e histórico de tudo que foi feito: `C:\Users\Win11-User\Documents\DisasterEvolution\fwjelaa-vault-0.1.0-new\fwjelaa\fwjelaa vault\90 Nosso Estudio\Contexto - Disaster Evolution.md`
- Design: `Design - Disaster Evolution (Tornado).md` na mesma pasta. Monetização (ainda em discussão): `Monetizacao - Disaster Evolution.md`.
- Ao terminar um trabalho, **acrescente uma seção nessa nota de Contexto** (o que mudou, arquivos, como testar, nº de testes).

## Projeto
- Rojo (`default.project.json`, porta 34874 via `ligar-rojo.bat`), um place só.
- `src/shared/Config` = todos os números. `src/shared/Logic` = lógica pura (sem Instances), testada em `tests/*.spec.luau`.
  `src/server/Match` = serviços do servidor. `src/client/City` = cliente do tornado/cidade. `src/client/Feedback.luau` = som+tremida+número (tipos em `FeedbackConfig`).
- Nomes de remotes só em `src/shared/Remotes/RemoteNames.luau`. O servidor decide tudo (dano, XP, recarga); cliente só pede e desenha.
- Comandos de teste no chat do Studio: `server/Match/DevCommands.luau` (`/lvl N`, `/max`, `/rebirths N`, `/help`...).

## Regras
- Depois de mudar código, rode **`lune run check fix`** na pasta do projeto (build + testes + Selene + StyLua) e só diga que está pronto se terminar com "Pipeline completo: tudo OK".
- Depois, rode a checagem do fwjelaa (hoje: 0 erros, 0 avisos, 10 "info" antigos):
  `powershell -NoProfile -ExecutionPolicy Bypass -File "C:/Vaults/fwjelaa/hooks/scripts/fwjelaa-check.ps1" -Scan src`
- Lógica nova não trivial → função pura em `Logic` + teste. Número novo → `Config`.
- Mudança mínima que resolve; não adicionar features fora da lista. Ideias novas vão para a lista "Pendente / próximo" da nota.
- **Não commitar sem o usuário pedir.** Branch atual: `evolution`. Sem remote.
- O Codex não consegue escrever em `.git` (proteção do sandbox). Para commitar: escreva a mensagem em `mensagem-commit.txt` na raiz e peça ao usuário para dar dois cliques em `commitar.bat` (faz `git add -A` + commit e apaga a mensagem). Confira antes com `git status` que só entram arquivos desta tarefa.
- Save de jogador (`server/PlayerData.luau`): trava de sessão e "load que falhou nunca salva" — não quebrar isso.
- UI: nada encostando, cabe em celular curto; área do analógico e do pulo livres. Sem número "+1" em clique.
- Seja crítico: aponte riscos e dê recomendação, não só concorde. Avise antes de tarefas caras.

## Próximo passo combinado (21/11)
1. Usuário testa no Studio (sozinho e com 2 jogadores) tudo que está marcado "falta testar" na nota.
2. Limpar a UI antiga do Destroy the City (dinheiro, gemas, UPGRADES, LOBBY, CREATE PARTY).
3. Calibrar números (`TornadoConfig`), depois monetização (discutir antes), depois página do jogo.
Features novas congeladas até lançar.
