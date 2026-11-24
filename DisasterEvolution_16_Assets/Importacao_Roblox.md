# DisasterEvolution — 16 assets 3D

## Organização

- `DisasterEvolution_16_Assets.blend` reúne as oito formas em **TORNADO_FORMS** e os oito efeitos em **Q_SKILLS**. Cada asset tem sua coleção e um objeto `<Nome>_ROOT` no chão. O .blend abre com os modelos dispostos em grade. Os exports individuais voltam para a origem `(0, 0, 0)`.
- `MAIN` agrupa a geometria ativa. Os grupos de impacto, rastro e implosão estão no mesmo FBX ou GLB para facilitar o transporte. No .blend, estão ocultos na galeria. Ative a visibilidade do grupo e de seus filhos para editá-los.
- `FBX/`, `GLB/` e `Renders/` têm um arquivo por asset. `Prancha_DisasterEvolution.png` reúne os 16 renders. `manifest.json` registra dimensões em unidades Blender, contagem de malhas, triângulos e grupos adicionais.
- Os materiais do .blend usam cores simples. Os exports também levam as cores por vértice. No GLB, a paleta fica nas cores por vértice, sobre a base neutra do formato.

## Importação para o Roblox Studio

1. Abra o **Importador 3D** em **Arquivo → Importar** e selecione o FBX do asset. Confira o tamanho na prévia antes de importar. O FBX exporta com Y para cima, enquanto o .blend usa Z para cima. As habilidades direcionais foram desenhadas apontando para +X.
2. Mantenha as peças separadas para que cada fase ou ciclone possa ser movimentado pelo seu pivô. Confira o chão em Y=0 e o pivô do Model. Se o importador agrupar ou descartar os Empties, refaça os grupos e pivôs a partir dos nomes e da hierarquia do .blend. Nos efeitos, confira a configuração de ancoragem e desligue colisão, toque e consulta nas peças cosméticas.
3. Confira as cores por vértice, especialmente ciano, amarelo e violeta, na prévia do Studio. O material do FBX e o atributo de cor do vértice estão disponíveis no arquivo. Ajuste a escala visual pelo raio da zona que o código já calcula e confirme a leitura em celular.

[Documentação do importador do Roblox](https://create.roblox.com/docs/pt-br/studio/importer) · [Cores de vértice](https://create.roblox.com/docs/art/blender#vertex-painting)

## Grupos das habilidades

| Habilidade | Visual principal | Subgrupos para o Roblox |
|---|---|---|
| Wind Burst | Lâminas de ar alongadas, apontadas para +X | `MAIN` |
| Dust Dash | Redemoinho baixo de poeira com fitas inclinadas | `DUST_IMPACT` |
| Vortex Slam | Espirais afunilando para um centro aberto | `VORTEX_IMPACT` |
| Twin Cyclones | Dois mini funis com pivôs independentes | `CYCLONE_A`, `CYCLONE_B`, `ORBIT_GUIDE`, `TWIN_IMPACT` |
| Eye of the Storm | Olho largo e estacionário | `EYE_IMPACT` |
| Tidal Surge | Crista volumétrica, espuma e spray | `FOAM`, `SURGE_IMPACT` |
| Inferno Spiral | Funil de chamas e fragmentos | `FIRE_TRAIL`, `FIRE_IMPACT` |
| Black Hole | Depressão escura e anéis gravitacionais | `GRAVITY_CORE`, `VOID_IMPLOSION` |

A trajetória, o tempo, a rotação, o crescimento e a troca de fase pertencem ao jogo. Os arquivos 3D entregam os pivôs e as malhas. O rastro do Inferno Spiral está separado para o sistema existente controlar seus 3 segundos. As formas e habilidades seguem os níveis 1, 4, 8, 12, 15, 19, 23 e 27 das configs do projeto. Este pacote é de assets e não muda a integração atual do Dust Dash nem valores de gameplay.

## Regeneração e validação

No diretório do pacote, com Blender 5.2.3 disponível como `blender`:

```powershell
blender -b --factory-startup --python-exit-code 1 --python Scripts/generate_assets.py
blender -b --factory-startup --python-exit-code 1 --python Scripts/verify_assets.py
powershell -NoProfile -ExecutionPolicy Bypass -File Scripts/make_board.ps1
```

A verificação reabre o .blend e reimporta os 32 arquivos no Blender, conferindo hierarquia, pivô, dimensões, malhas, triângulos e presença de dados de cor. A validação de aparência e desempenho dentro do Roblox Studio fica para a integração.

