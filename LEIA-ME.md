# Eat City — Rojo + Lune + VS Code

## Instalar as ferramentas (só na primeira vez)

1. Instale o **Rokit**: https://github.com/rojo-rbx/rokit/releases (arquivo `windows-x86_64.zip`, depois `.\rokit.exe self-install`).
2. Dentro desta pasta, no terminal do VS Code:
   ```powershell
   rokit install
   rojo plugin install
   ```

## Uso no dia a dia

| O que | Comando |
|---|---|
| Ligar o Rojo (sincronizar com o Studio) | `rojo serve` → no Studio: Plugins → Rojo → Connect |
| **Pipeline completo** (build + testes + linter + formatter) | `lune run check` |
| Pipeline formatando os arquivos antes | `lune run check fix` |
| Só os testes | `lune run test` |
| Relatório de ritmo da progressão | `lune run balance` |

## Onde fica cada coisa

- `src/shared/Config/` → todos os números do jogo (mapas, tiers, upgrades, classes, loja, roleta, recompensas, Robux, UI, animações)
- `src/shared/Config/ProductConfig.luau` → IDs dos produtos de Robux (preencher depois de publicar o jogo)
- `src/shared/Logic/` → matemática pura, testável sem o Studio
- `src/shared/Buildings/Templates.luau` → formato de cada construção
- `src/shared/Remotes/RemoteNames.luau` → nomes de todos os RemoteEvents/Functions
- `src/server/` → servidor (partidas, lobby, comer, loja, roleta, recompensas, dados salvos)
- `src/client/` → cliente (interfaces, efeitos, animações, câmera)
- `src/overrides/` → substituem o Animate e os sons de passos padrão do Roblox
- `tests/` → testes (rodam no PC com `lune run test`)
