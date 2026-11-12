# eatCity — Rojo + Wally + VS Code

## Instalar as ferramentas (só na primeira vez)

1. Baixe o **Rokit** (gerenciador das ferramentas): https://github.com/rojo-rbx/rokit/releases
   Pegue o arquivo `windows-x86_64.zip`, extraia, e no PowerShell, dentro da pasta extraída:
   ```powershell
   .\rokit.exe self-install
   ```
   Feche e abra o PowerShell de novo.

2. Dentro desta pasta do projeto:
   ```powershell
   cd $HOME\Documents\eatCity
   rokit init
   rokit add rojo-rbx/rojo
   rokit add UpliftGames/wally
   rokit add JohnnyMorganz/StyLua
   rokit add Kampfkarren/selene
   rokit add lune-org/lune
   rojo plugin install
   ```

3. Abra a pasta no VS Code (`code .`) e aceite instalar as extensões recomendadas.

## Uso no dia a dia

| O que | Comando |
|---|---|
| Baixar pacotes do Wally | `wally install` |
| Ligar o Rojo (sincronizar com o Studio) | `rojo serve` → no Studio: aba Plugins → Rojo → Connect |
| 1. Build | `rojo build -o jogo2.rbxl` |
| 2. Testes | `lune run tests/Economy.spec` |
| 3. Linter | `selene src` |
| 4. Formatter | `stylua src tests` |

## Onde fica cada coisa

- `src/shared/Config/` → todos os números do jogo (preços, velocidade, etc.)
- `src/shared/Remotes/RemoteNames.luau` → todos os nomes de RemoteEvents
- `src/shared/Logic/` → matemática pura, testável sem o Studio
- `src/server/` → vira `ServerScriptService.Server`
- `src/client/` → vira `StarterPlayerScripts.Client`
- `Packages/` → criada pelo `wally install` (não edite à mão)
