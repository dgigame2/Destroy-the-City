# Diagnóstico — Destroy the City (18/11/2026)

Base: planejamento geral + atualização "Tutorial, Lobby e Multiplayer". Nada foi alterado no código.
Pipeline local (`lune run check`): build OK, **1092 testes passam, 1 falha** (`tests/LobbyTown.spec:71` — casas/árvores do lobby encostando).

---

## 1. Diagnóstico geral da estrutura

- Rojo + Lune + Selene + StyLua. Código bem separado: `shared/Config` (números), `shared/Logic` (matemática pura, testada), `server/*Service`, `client/Controllers`. Isso já atende ao requisito de arquitetura modular — **manter**.
- **Dois places na mesma experiência**: `Lobby` (default.project.json) e `Run` (run.project.json). O mesmo código roda nos dois; `Place.isRun()` decide o que liga (`server/init.server.luau`).
- **Fluxo atual**: lobby → quadrados "START A RUN" (`PartyService`) → tela CREATE PARTY (mapa, dificuldade, tamanho, ou carregar run salva) → `Teleporter.toRun` cria **um servidor reservado por party** → `RunSession` monta a cidade, a party destrói tudo, zonas abrem em sequência → vitória (gemas + 1 win) → volta ao lobby.
- **Dados**: `PlayerData` (DataStore `EatCity_PlayerData_v1`: gemas, wins, itens, recompensas, roleta, runs salvas) e `RunStore` (DataStore `EatCity_Runs_v1`: estado da run por party). Dinheiro, upgrades e poder são **da run**, não da conta.
- **Remotes**: centralizados em `shared/Remotes/RemoteNames.luau` (17 eventos, 9 funções). Desastre é autoritativo no servidor (cliente só pede; `DisasterService` valida cooldown, alcance, chão liberado).
- **Legado do "Eat City"**: `EatService`, `GrowthService` (pontos → tamanho), `EatEffects`, `EatIndicator`, eventos `BuildingEaten`, `GameplayConfig.Mode = "Eat"` como rollback. Ainda carregados na Run.

## 2. Estado de cada sistema

| Sistema | Onde | Estado |
|---|---|---|
| Desastres (Meteor, Tornado, Bolt) com papéis distintos | `DisasterConfig`, `Logic/Disasters`, `DisasterService`, `DisasterVfx` | Funcional — mecânicas realmente diferentes (ponto / linha / pulos) |
| Vida, estágios de dano, desabar em escombros | `DamageService`, `DamageStages`, `Ruins`, `DamageVfx` | Funcional (falta validar no Studio, segundo o CONTEXTO) |
| Reações em cadeia (explosão, fogo, condutor) e destroços voando | `ChainConfig`, `Logic/Chain`, `DebrisService` | Funcional, com tetos |
| Feedback (som/visual) | `client/Feedback.luau`, `FeedbackConfig`, `AudioConfig` | Implementado, precisa melhorar (som concentrado num só módulo; validar "satisfação" com jogadores) |
| Cidades (geração por plantas, zonas, litoral) | `CityGen`, `CityPlans`, `MapService`, `Templates`, `MeshKit` | Funcional; identidade própria por mapa ainda limitada |
| **Reconstrução automática da cidade** | — | **Ausente** (a run termina quando tudo cai; prédio não volta) |
| Dinheiro (Coins) | `TierConfig`, `PlayerData` | Implementado, mas **zera a cada run** — conflita com o core loop |
| Upgrades | `UpgradeConfig` (Recharge, Reach, Xp, Coins; 10 níveis, +% por nível) | Problemático — são só números, contra a regra do planejamento |
| Evolução dos desastres | `MasteryService` (30 níveis por XP, +5% dano / +1,2% tamanho) | Problemático — 30 níveis numéricos, por run; aprovado é ~5 níveis permanentes que mudam comportamento |
| Progressão permanente | Wins liberam mapas/dificuldades; gemas | Incompleto |
| Salvamento | `PlayerData` (GetAsync/SetAsync), `RunStore` | Implementado, precisa melhorar (sem session lock; corrida no teleporte) |
| Recompensa diária + sequência (streak) e semanal | `StoreService`, `RewardConfig` | Funcional |
| Recompensa por tempo de jogo | — | Ausente |
| Missões e desafios | — | Ausente |
| Eventos | — | Ausente |
| Modificadores de partida | Dificuldades (EASY/MEDIUM/HARD) | Incompleto — mudam tamanho/ritmo, não a experiência |
| Coleções e conquistas | — | Ausente |
| Metas coletivas por servidor | Zonas da cidade (party inteira libera a área) | Incompleto — sem validação de participação |
| Placar individual | `StatsService` (leaderstats) | Funcional |
| Parties | `PartyService`, `PartyController`, `Logic/Party` | Implementado, precisa mudar (party só existe em cima do quadrado; sem convite) |
| Convites de amigos | — | Ausente |
| Matchmaking | — | Ausente (hoje: 1 servidor reservado fechado por party) |
| Tutorial | — | Ausente |
| Guia visual no lobby | `GuidePath` + setas do `ZoneController` (só dentro da run) | Reaproveitável |
| Lobby (ilha, loja, roleta, recompensas, classes) | `LobbyService` (1181 linhas, monta tudo por código) | Funcional |
| Loja de gemas, trails, auras, roleta, classes, Robux | `StoreService`, `ShopConfig`, `WheelConfig`, `ClassConfig`, `ProductConfig` | Funcional, mas **parte é "adiado" no planejamento** (auras, cosméticos, loja cosmética) |
| Analytics / funis | — | Ausente |
| Interface PC/mobile | `Ui/Screens`, `Style`, `UiLayout` (+ testes de layout) | Implementado, precisa validar em celular real |
| Modo "Eat" legado | `EatService`, `GrowthService`, `EatEffects`, `EatIndicator` | Desnecessário no momento (dívida técnica) |

## 3. Problemas técnicos encontrados

1. **Teste falhando**: `tests/LobbyTown.spec:71` (objetos do lobby encostando — regra "nada de peças sobrepostas").
2. **Salvamento sem trava de sessão**: `PlayerData` usa `GetAsync`/`SetAsync`. Com teleporte lobby ↔ run, um servidor pode carregar dados antigos e depois sobrescrever o outro (risco real de perder gemas/wins). O lobby salva antes do teleporte, mas a run salva também no `PlayerRemoving` — que pode acontecer depois que o lobby já carregou.
3. **Run rejeita quem não é membro** (`RunSession.onPlayerReady` → manda ao lobby). Incompatível com matchmaking.
4. **Studio não teleporta**: tudo que envolve lobby ↔ run só é testável no jogo publicado (precisa de um place "Run" na experiência de teste).
5. **Código do modo Eat sempre carregado na Run** (`EatService.start()` roda mesmo no modo Disasters).
6. Remotes sem limite de frequência genérico (o `UseDisaster` tem cooldown; os outros dependem da validação de cada handler — ok hoje, mas sem padrão).

## 4. Problemas de arquitetura

1. **Modelo "run" × core loop aprovado.** Hoje: cidade não volta, dinheiro/upgrades/níveis zeram por run, objetivo é zerar a cidade. Aprovado: Destruir → Dinheiro → Evoluir → Repetir, cidade que se reconstrói e progressão permanente. É o maior conflito do projeto e afeta quase todos os outros itens.
2. **Runs salvas por party** (`RunStore`, `SavedRuns`, LOAD GAME) prendem a cidade a um grupo fixo — conflita com cidades de até 4 jogadores com matchmaking.
3. **Party amarrada ao quadrado físico**: não dá para montar party antes, convidar amigo, nem manter a party entre partidas.
4. **Escolha de mapa + dificuldade + tamanho** por party fragmenta servidores se virar matchmaking (cada combinação vira um "balde" separado).
5. **Duas progressões paralelas de poder** (Upgrades + Mastery + Classes + GrowthService/Points) — muitos números somando, difícil de balancear e de entender.

## 5. Riscos de performance

- Tetos já existem: `MaxActive` desastres 12, `MaxTargetsPerHit` 60, destroços voando 14 (física no servidor), fogo 8, cadeia 40/depth 4. Bom ponto de partida, **mas nunca foi medido com 4 jogadores reais**.
- **Quantidade de peças da cidade**: modelos em blocos (Voxel/Templates) multiplicam partes; com `StreamingEnabled = false` a cidade inteira replica para todo celular.
- **Replicação**: `BuildingDamaged`, `BuildingCracked`, `BuildingCollapsed` mandam listas de peças para todos a cada golpe; com 4 jogadores e cadeias isso pode estourar banda.
- **Reconstrução** (quando existir): recriar modelos inteiros de uma vez gera pico de instâncias e replicação → precisa ser em lotes/pool.
- Escombros ficam dentro dos modelos até a vida acabar (mais partes vivas por mais tempo).
- Limitar a 4 jogadores **não resolve** sozinho (concordo com a atualização): o custo vem de objetos, física, efeitos e rede.

## 6. Sistemas que precisam ser criados

Reconstrução da cidade · progressão permanente (dinheiro e níveis salvos na conta) · 5 níveis por desastre com mudança de comportamento · tutorial · guia de primeira chegada no lobby · party persistente + convites · matchmaking · recompensa por tempo de jogo · missões · conquistas/coleções (simples) · metas coletivas com validação de participação · modificadores · eventos · analytics (funil de onboarding, uso de desastres, progressão, abandono) · medição de performance.

## 7. Sistemas que precisam ser corrigidos

Salvamento (session lock / `UpdateAsync`) · upgrades genéricos (virar níveis dos desastres) · Mastery de 30 níveis por run · `PartyService` (separar party do quadrado) · `RunSession` (aceitar entradas, capacidade configurável, sem "membros fixos") · `Teleporter` (falhas/retentativa, grupos) · teste do `LobbyTown` · remover/isolar o modo Eat.

## 8. Plano de implementação (ordem de prioridade)

**Fase 0 — Base (pequeno, sem mudar design)**
1. Corrigir o teste do `LobbyTown`.
2. Salvamento confiável: `UpdateAsync` + trava de sessão no `PlayerData`; salvar e liberar a trava antes de teleportar.
3. Medição: módulo de métricas no Studio (partes vivas, destroços, desastres ativos, KB/s enviados, tempo de física) para ter números antes de mexer.

**Fase 1 — Core loop (depende das decisões 1–4)**
4. Cidade que se reconstrói (por construção ou por zona, em lotes, reaproveitando `Builder`/`MapService`).
5. Dinheiro e níveis permanentes na conta; 5 níveis por desastre com mudança real (ex.: Meteor nv3 se divide em fragmentos; Tornado nv3 puxa destroços; Bolt nv3 encadeia em condutores sem perder força). Reaproveita `Logic/Disasters`, `UpgradeService`, `LevelsController`.
6. Desligar o modo Eat e as progressões duplicadas.

**Fase 2 — Performance**
7. Teste com 4 clientes (Studio "Local Server, 4 players" no place Run, que roda sem teleporte), avaliar `StreamingEnabled`, agrupar replicação dos golpes, orçamento de partes. Capacidade definida pelos números, não por chute.

**Fase 3 — Multiplayer (atualização nova)**
8. Party persistente no lobby (convidar jogador do servidor + `SocialService:PromptGameInvite` para amigos fora). Quadrados viram só o ponto "JOGAR".
9. Matchmaking com `MemoryStoreService`: cada servidor de cidade publica vagas (heartbeat + TTL); o lobby reserva N vagas de forma atômica para o grupo inteiro, teleporta com o código do servidor reservado; sem vaga → cria servidor novo. Preenche servidores existentes antes de abrir novos (evita fragmentação). `MatchConfig.MaxPlayers = 4` (place Run com MaxPlayers ≥ esse valor).
   - Falha de teleporte: libera a reserva, tenta de novo 1x, depois avisa.
   - Partida lotou no meio: servidor da cidade recusa e devolve ao lobby, que refaz a busca.
   - Desconexão: `PlayerRemoving` libera vaga; reservas expiram sozinhas.
   - Party mudou durante a busca: cancela a busca e o líder confirma de novo.
   - Integrante que não conseguiu ir: recebe opção "seguir a party" (mesmo código, se houver vaga).
10. Run aceita jogadores entrando a qualquer momento.

**Fase 4 — Onboarding**
11. Tutorial no place Run, servidor reservado solo, mapa pequeno, passos guiados (usar desastre → destruir → ganhar → evoluir). Estado no `PlayerData` (`Tutorial = {Done, Step}`), primeira entrada redireciona, continuar/reiniciar, repetir pelo lobby.
12. Seta de primeira chegada no lobby (reaproveita `GuidePath` + chevrons do `ZoneController`).
13. Analytics com `AnalyticsService` (funil de onboarding, economia, progressão, uso de desastres, jogando junto).

**Fase 5 — Retenção** (só depois do core validado com jogadores)
14. Recompensa por tempo de jogo → missões → conquistas/coleções → meta coletiva do servidor → modificadores → eventos.

**Fase 6 — Apresentação**: ícone, thumbnail e vídeo do gameplay real; revisão mobile.

**Critérios de sucesso**: pipeline 100% verde; 4 jogadores destruindo ao mesmo tempo sem queda de FPS em celular médio (meta a definir na Fase 0); nenhum dado perdido em 50 teleportes seguidos; party de 4 sempre chega junta ou recebe opção de seguir; novo jogador entende o próximo passo no lobby sem menu.

## 9. Decisões que precisam da sua aprovação

1. **Modelo de partida**: trocar "run que termina" por **cidade persistente que se reconstrói** (recomendado; é o que o planejamento pede). Consequência: runs salvas, LOAD GAME, "vitória por zerar" e `RunStore` saem ou viram outra coisa (ex.: limpar zona = marco com prêmio).
2. **Dinheiro e evolução permanentes** na conta (recomendado). Hoje zeram por run.
3. **Evolução**: substituir Mastery (30 níveis, XP, por run) + upgrades genéricos por **5 níveis por desastre comprados com dinheiro**, cada nível mudando comportamento (recomendado).
4. **Moedas**: manter só Coins (progressão) + Gems (prêmios/Robux). Nenhuma moeda nova.
5. **Cosméticos/roleta/auras/classes**: congelar (ficam funcionando, sem trabalho novo). Classes somam mais um bônus de números — recomendo revisar depois.
6. **Escolha de mapa/dificuldade com matchmaking**: recomendo matchmaking por **cidade** apenas (dificuldade vira modificador de partida ou sai), para não fragmentar servidores.
7. **Onde roda o tutorial**: place Run em servidor solo (recomendado; reaproveita desastres e física e não pesa o lobby) × dentro do lobby.
8. **Remover o modo Eat** legado (recomendado; o rollback deixa de fazer sentido com a Fase 1).
9. **Validação de participação** nas metas coletivas: ex. dano mínimo causado + tempo ativo na janela da meta.
