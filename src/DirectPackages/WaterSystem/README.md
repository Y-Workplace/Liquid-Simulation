# WaterSystem

Port client-side do GodotOceanWaves para Roblox Luau usando `EditableMesh`.

O sistema observa `Workspace.Water`. Cada `BasePart` dentro dessa pasta vira um tile de oceano gerado em `Workspace.GeneratedOcean`. O `Part` original define area, rotacao e altura da superficie; por padrao ele fica invisivel localmente para o jogador. Se `Workspace.Water` tiver subfolders como `Ocean_A`, `Ocean_B`, cada Folder funciona como um oceano independente e seus Parts herdam os atributos desse Folder.

## Uso

O `GameplayClient` ja inicia o sistema:

```lua
local WaterSystem = require(ReplicatedStorage.DirectPackages.WaterSystem)

local ocean = WaterSystem.new()
ocean:Start()
```

As opcoes por codigo podem ser passadas no formato antigo plano ou agrupadas por contexto:

```lua
local ocean = WaterSystem.new({
	Foam = {
		TextureResolution = 64,
		ShoreStrength = 0.08,
	},
	Waves = {
		ShallowScale = 0.12,
	},
})
```

Para consultar altura:

```lua
local height = WaterSystem.GetHeight(worldPosition)
local normal = WaterSystem.GetNormal(worldPosition)
local velocity = WaterSystem.GetVelocity(worldPosition)
```

`GetHeight`, `GetNormal` e `GetVelocity` retornam `nil` quando a posicao nao cai sobre nenhum tile carregado em `Workspace.Water`.

Para criar ripples/splashes na camada fisica:

```lua
WaterSystem.Splash(worldPosition, 0.34, 8)
WaterSystem.Explosion(worldPosition, 1.2, 28)
WaterSystem.MoveSphere(oldWorldCenter, newWorldCenter, radius, strengthScale)
```

## Painel runtime

O sistema cria um painel runtime estilo Godot/ImGui quando o cliente inicia.

- `Ctrl-H`: alterna visibilidade.
- `Ctrl-F`: alterna fullscreen.
- Sliders e dropdowns escrevem atributos em `Workspace.Water`.
- Mudancas de ondas atualizam o espectro sem recriar a malha.
- Mudancas de resolucao/cor/material recriam os tiles gerados.

## Atributos em `Workspace.Water`

- `OceanResolution` number: teto de vertices por eixo de cada tile. Padrao `96`, minimo `2`, maximo `160`.
- `OceanVertexSpacing` number: espacamento alvo em studs entre vertices. Padrao `9`. Oceanos pequenos e grandes usam densidade parecida; `OceanResolution` limita o teto.
- `OceanUpdatesPerSecond` number: taxa near/fallback de atualizacao da malha. Padrao `30`; use `0` para todo frame perto da camera.
- `OceanLoadDistance` number: distancia em studs para criar `EditableMesh` de um Part fonte. Padrao `1024`.
- `OceanUnloadDistance` number: distancia em studs para destruir o tile gerado e liberar o `EditableMesh`. Padrao `1152`.
- `OceanLodScanInterval` number: intervalo do scan de load/unload por distancia. Padrao `0.35`.
- `OceanNearUpdateDistance` number: ate onde usar `OceanNearUpdatesPerSecond`. Padrao `256`.
- `OceanMidUpdateDistance` number: ate onde usar `OceanMidUpdatesPerSecond`. Padrao `512`.
- `OceanNearUpdatesPerSecond` number: update rate dos tiles perto da camera. Padrao `30`.
- `OceanMidUpdatesPerSecond` number: update rate dos tiles em distancia media. Padrao `8`.
- `OceanFarUpdatesPerSecond` number: update rate dos tiles longe, mas ainda carregados. Padrao `2`.
- `OceanPhysicsDistance` number: distancia em studs para simular ripples/interacao fisica por tile. Fora dela o sistema nem entra no scan/simulacao de fisica. Padrao `220`.
- `OceanFoamDistance` number: distancia em studs para atualizar/amostrar foam local, sea spray e splashes de obstaculo. Fora dela o foam dinamico e limpo e nao e recalculado. Padrao `220`.
- `OceanInteractiveWavesEnabled` boolean: ativa a camada WebGL-style/height-field por `WaterBuffer`. Padrao `true`.
- `OceanInteractiveResolution` number: resolucao do buffer fisico por tile. Padrao `64`, maximo `256`.
- `OceanInteractiveSimulationIterations` number: iteracoes do solver por update do tile. Padrao `1`.
- `OceanInteractiveDamping` number: damping dos ripples fisicos. Padrao `0.992`.
- `OceanInteractiveMaxHeight` number: clamp de altura da camada interativa. Padrao `5`.
- `OceanInteractiveMaxVelocity` number: clamp de velocidade da camada interativa. Padrao `8`.
- `OceanInteractiveMoveSphereScale` number: escala de deslocamento para `MoveSphere`. Padrao `0.18`.
- `OceanInteractiveFoamStrength` number: quanto slope/velocidade do buffer fisico vira foam. Padrao `0.85`.
- `OceanInteractiveFoamSlopeThreshold` number: slope minimo do buffer para foam. Padrao `0.16`.
- `OceanInteractiveFoamVelocityThreshold` number: velocidade minima do buffer para foam. Padrao `0.18`.
- `OceanInteractiveLodDissipation` number: fator de fade aplicado a ondas interativas quando saem do LOD de fisica. Padrao `0.82`.
- `OceanDepthMapEnabled` boolean: ativa raycast inicial de profundidade por tile. Padrao `true`.
- `OceanDepthMapResolution` number: resolucao do mapa de profundidade. Padrao `12`.
- `OceanMaxRaycastDepth` number: profundidade maxima do raycast. Padrao `180`.
- `OceanFallbackDepth` number: profundidade usada quando o raycast nao acha fundo. Padrao `180`.
- `OceanShallowWaveScale` number: escala de onda em agua rasa/praia. Padrao `0.12` para manter ondas amortecidas, mas ainda visiveis onde o `DepthMap` raycastado indica pouca profundidade.
- `OceanDeepWaveScale` number: escala de onda em agua profunda. Padrao `1.08`.
- `OceanBeachWaveCurl` number: curva lateral aplicada a ondas rasas usando o gradiente do `DepthMap`, para formar linhas de quebra mais sinuosas tipo praia. Padrao `0.78`.
- `OceanShallowDepth` number: ate onde a agua e tratada como rasa. Padrao `10`.
- `OceanLakeDepth` number: profundidade onde a cascade media/lago domina. Padrao `42`.
- `OceanOceanDepth` number: profundidade onde a cascade grande/oceano domina. Padrao `96`.
- `OceanWaveLoopFrames` number: frames do loop baked de deslocamento e foam por tile. Padrao `48`.
- `OceanWaveLoopDuration` number: duracao em segundos do loop baked. Padrao `18`.
- `OceanFarWaveDetail` number: porcentagem dos componentes Gerstner usados em LOD distante. Padrao `0.42`.
- `OceanLod0Radius` number: raio em studs do anel LOD0 ao redor da camera. Usa densidade total, fisica visual e foam completa. Padrao `220`.
- `OceanLod1Radius` number: raio em studs do anel LOD1. Usa stride medio e foam baked simplificada. Padrao `512`.
- `OceanLod2Radius` number: raio em studs do anel LOD2. Usa stride distante e sem foam. Apos ele usa stride extremo. Padrao `1024`.
- `OceanLodRecenterDistance` number: quantos studs a camera precisa andar para recentralizar/rebakear o cache de indices dos aneis. Padrao `64`.
- `OceanVolumeEnabled` boolean: gera laterais e fundo simples para o tile parecer volume de agua. Padrao `true`.
- `OceanVolumeSideSpacing` number: espacamento em studs dos vertices das laterais. Padrao `36`.
- `OceanVolumeVerticalSegments` number: segmentos verticais das laterais. Padrao `3`.
- `OceanVolumeBottomResolution` number: resolucao baixa do fundo. Padrao `6`.
- `OceanVolumeWaveScale` number: quanto laterais/fundo acompanham a onda baked. Padrao `0.18`.
- `OceanVolumeMinDepth` number: profundidade visual minima usada pela malha volumetrica quando o raycast encontra agua muito rasa. Padrao `3.5`.
- `OceanChunkLodEnabled` boolean: ativa LOD externo por chunk inteiro. Padrao `true`.
- `OceanChunkLod0Distance`, `OceanChunkLod1Distance`, `OceanChunkLod2Distance` number: limiares em studs para LOD0/1/2. Padroes `100`, `300`, `600`.
- `OceanChunkLodHysteresis` number: margem em studs para evitar troca repetida de LOD perto do limite. Padrao `64`.
- `OceanChunkLodSwitchCooldown` number: tempo minimo em segundos entre reconstrucoes de LOD do mesmo chunk. Padrao `0.85`.
- `OceanChunkLod0Resolution`, `OceanChunkLod1Resolution`, `OceanChunkLod2Resolution`, `OceanChunkLod3Resolution` number: resolucoes por LOD externo. Padroes `96`, `64`, `32`, `16`.
- `OceanViewCullingEnabled` boolean: pula update visual de tiles fora do campo de visao. Simulacao e interacao continuam. Padrao `true`.
- `OceanViewCullingPadding` number: margem em studs do teste de visibilidade. Padrao `96`.
- `OceanMidLodVertexStep` number: stride de vertices atualizado no LOD medio. Padrao `2`.
- `OceanFarLodVertexStep` number: stride de vertices atualizado no LOD distante. Padrao `4`.
- `OceanExtremeLodVertexStep` number: stride de vertices atualizado fora de `OceanLod2Radius`. Padrao `8`.
- `OceanObstacleMapEnabled` boolean: ativa mapa de obstaculos via raycast. Padrao `true`.
- `OceanObstacleRootName` string: pasta de obstaculos/rochas para espuma e damping. Padrao `WaterObstacles`.
- `OceanBakeAnchoredObstacles` boolean: inclui objetos estaticos `Anchored = true` no bake de obstaculo, ignorando `Workspace.Water` e `GeneratedOcean`. Padrao `true`.
- `OceanObstacleFoamStrength` number: foam gerado perto de obstaculos. Padrao `0.9`.
- `OceanObstacleWaveDamping` number: reducao de onda perto de obstaculos. Padrao `0.65`.
- `OceanFoamBufferEnabled` boolean: ativa o campo vivo de superficie para efeitos fisicos/interativos. Padrao `true`.
- `OceanFoamBufferResolution` number: resolucao do buffer de superficie por tile. Padrao `48`.
- `OceanFoamBufferDecay` number: dissipacao por segundo aplicada ao foam persistente de praia, obstaculo e interacao. Padrao `0.72`.
- `OceanFoamBufferGrowth` number: velocidade com que fontes continuas escrevem no campo de superficie. Padrao `7.5`.
- `OceanShoreFoamStrength` number: foam gerado por agua rasa/praia, usando a mesma profundidade raycastada que deixa a agua mais verde no raso, separado do foam de crista das ondas grandes. Padrao `0.42`.
- `OceanFoamTrailStrength` number: intensidade do rastro fino de espuma em agua rasa. E composto como camada separada, abaixo da crista/quebra. Padrao `0.34`.
- `OceanFoamTrailLength` number: distancia normalizada do rastro da praia para dentro da agua rasa; valores maiores espalham mais wash/lace. Padrao `2.4`.
- `OceanFoamTrailFeather` number: suavidade da borda do rastro de espuma. Padrao `0.58`.
- `OceanCrestFoamAlphaBack` number: alpha do foam de crista quando a mascara fina de crista e `0`. Padrao `0`.
- `OceanCrestFoamAlphaTop` number: alpha do foam de crista quando a mascara fina de crista e `1`. Padrao `1`.
- `OceanCrestFoamAlphaGain` number: ganho do gradiente de alpha do foam de crista. A mascara comeca perto do topo da onda e valores maiores deixam a espuma menos transparente e mais acumulada na crista, separado do gradiente verde da agua. Padrao `1`.
- `OceanWaveFoamAlphaBack` number: alpha inicial da camada larga de foam no corpo da onda. Padrao `0`.
- `OceanWaveFoamAlphaTop` number: alpha maximo da camada larga de foam acumulada perto do topo da onda. Padrao `0.42`.
- `OceanWaveFoamAlphaGain` number: ganho da camada larga de foam de ondas; menor deixa o desenho mais suave, maior aproxima do topo. Padrao `0.78`.
- `OceanCausticsEnabled` boolean: ativa caustics procedurais na cor da superficie. Padrao `true`.
- `OceanCausticsStrength` number: intensidade global do efeito. Padrao `0.32`.
- `OceanShallowCausticsStrength` number: linhas de caustics visiveis em agua rasa/praia. Padrao `1`.
- `OceanDeepCausticsStrength` number: brilho residual em oceano profundo. Padrao `0.13`.
- `OceanCausticsScale` number: escala em studs do pattern. Padrao `18`.
- `OceanCausticsSpeed` number: velocidade da animacao procedural. Padrao `0.42`.
- `OceanCausticsDepthFade` number: quao rapido as caustics fortes somem com a profundidade normalizada. Padrao `0.42`.
- `OceanCausticsVoronoiStrength` number: quanto Voronoi discreto entra no oceano profundo, misturado a ruido suave. Padrao `0.18`.
- `OceanPhysicalInteractionEnabled` boolean: ativa interacao automatica com partes fisicas. Padrao `true`.
- `OceanPlayerInteractionEnabled` boolean: usa apenas `HumanoidRootPart` como caixa do player. Padrao `true`.
- `OceanBuoyancyEnabled` boolean: ativa empuxo automatico em Parts nao anchored, separado do player. Padrao `true`.
- `OceanBuoyancyStrength` number: forca extra de empuxo por profundidade, combinada com flutuacao por submersao. Padrao `22`.
- `OceanBuoyancyDamping` number: damping vertical por ponto de flutuacao. Padrao `6`.
- `OceanBuoyancyLinearDrag` number: drag linear proporcional a submersao. Padrao `1.15`.
- `OceanBuoyancyAngularDrag` number: drag angular proporcional a submersao. Padrao `0.9`.
- `OceanBuoyancyScanInterval` number: intervalo do scan de buoyancy. Padrao `0.1`.
- `OceanBuoyancyMaxParts` number: limite de Parts processados por scan. Padrao `96`.
- `OceanPlayerSurfaceFloatEnabled` boolean: faz o player acompanhar suavemente a superficie quando perto dela, sem empuxo fisico. Padrao `true`.
- `OceanPlayerSurfaceInfluenceDepth` number: faixa vertical onde ondas influenciam o player. Padrao `3.5`.
- `OceanPlayerSurfaceSmoothness` number: suavidade do acompanhamento de superficie. Padrao `10`.
- `OceanPlayerSurfaceOffset` number: offset vertical do `HumanoidRootPart` em relacao a superficie bakeada. Padrao `-0.35`.
- `OceanPlayerSurfaceMaxVerticalSpeed` number: limite da velocidade vertical aplicada pela boia do player. Padrao `18`.
- `OceanPlayerSwimAnimationEnabled` boolean: carrega `Animate.swim.Swim` e `Animate.swimidle.SwimIndle`/`SwimIdle` do proprio character. Padrao `true`.
- `OceanPlayerSwimMovementThreshold` number: limiar para alternar entre swim e swimidle. Padrao `0.12`.
- `OceanPlayerSwimDepth` number: profundidade para entrar em `Swimming`. Padrao `2.8`.
- `OceanUnderwaterEffectsEnabled` boolean: ativa color correction, blur e fog submersos. Padrao `true`.
- `OceanUnderwaterDepthStart` number: profundidade inicial do efeito. Padrao `0.25`.
- `OceanUnderwaterDepthFull` number: profundidade onde o efeito chega ao maximo. Padrao `18`.
- `OceanUnderwaterDepthOfFieldEnabled` boolean: ativa `DepthOfFieldEffect` submerso e restaura o valor anterior ao sair. Padrao `true`.
- `OceanUnderwaterDepthOfFieldFocusDistance`, `OceanUnderwaterDepthOfFieldInFocusRadius`, `OceanUnderwaterDepthOfFieldNearIntensity`, `OceanUnderwaterDepthOfFieldFarIntensity`: ajuste fino do DOF submerso.
- `OceanCameraDropsEnabled` boolean: cria gotas de vidro temporarias ao entrar/sair da agua. Padrao `true`.
- `OceanCameraDropCount` number: quantidade de gotas por transicao. Padrao `14`.
- `OceanCameraDropDuration` number: duracao das gotas em segundos. Padrao `1.4`.
- `OceanPhysicalImpactSpeed` number: velocidade vertical minima para splash forte. Padrao `8`.
- `OceanPhysicalRadiusScale` number: escala do raio usado para objetos fisicos e area de splash. Padrao `0.55`.
- `OceanSplashParticlesEnabled` boolean: ativa particulas em impactos. Padrao `true`.
- `OceanSplashParticleTextureId` string: AssetID opcional para particulas de splash; se vazio, reaproveita `OceanSeaSprayTextureId`.
- `OceanComponentCount` number: reservado para o modo espectral antigo; o modo atual usa 8 Gerstner waves fixas.
- `OceanMaxDistance` number: distancia em studs para achatar tiles longe da camera. Padrao `1024`.
- `OceanFadeStartDistance` number: distancia onde o deslocamento comeca a cair. Padrao `512`.
- `OceanHeightScale` number: escala vertical global. Padrao `1.15`.
- `OceanChoppiness` number: deslocamento horizontal das cristas. Padrao `1`.
- `OceanTimeScale` number: velocidade da simulacao. Padrao `1`.
- `OceanSeed` number: estado deterministico das ondas. Padrao `1234`.
- `OceanWindSpeed` number: vento medio, equivalente ao parametro Godot. Padrao `20`.
- `OceanWindDirection` number: direcao em graus no plano XZ. Padrao `0`.
- `OceanFetchLength` number: distancia de fetch em km. Padrao `550`.
- `OceanSwell` number: swell, intervalo util `0..2`. Padrao `0.8`.
- `OceanSpread` number: abertura direcional, intervalo `0..1`. Padrao `0.2`.
- `OceanDetail` number: atenuacao de frequencias altas, intervalo `0..1`. Padrao `1`.
- `OceanWhitecap` number: limiar de espuma. Padrao `0.5`.
- `OceanFoamAmount` number: intensidade de espuma. Padrao `5`.
- `OceanWaterColor` Color3: `ColorBack`, cor da agua no ponto `0` do gradiente por tamanho de onda.
- `OceanWaterTintColor` Color3: `ColorTop`, cor da agua no ponto `1` do gradiente por tamanho de onda. Padrao `Color3.fromRGB(31, 143, 128)`.
- `OceanWaterAlphaGain` number: ganho do alpha por profundidade; valores maiores deixam a agua ficar opaca mais cedo ao sair do raso, valores menores mantem a borda rasa mais transparente. Padrao `1`.
- `OceanFoamColor` Color3: cor de espuma.
- `OceanSurfaceColorBake` boolean: `true` pre-bakeia todos os frames de cor/foam em RGBA e, em runtime, apenas aplica o frame pronto nos vertices ou no `EditableImage`; `false` mantem o caminho antigo que calcula cor/foam por frame. O alpha da agua vem da profundidade raycastada pelo `DepthMap`. Padrao `true`.
- `OceanSurfaceColorMode` string: `"SurfaceAppearance"`, `"FoamSurfaceAppearance"` ou `"PaintVertices"`. `PaintVertices` pinta vertices e tambem cria um `SurfaceAppearance` vazio para o pipeline de render do Roblox; os modos com textura criam um `EditableImage` na resolucao de `OceanFoamTextureResolution`. Padrao `"PaintVertices"`.
- `Bake`/`Mode` nas opcoes por codigo funcionam como aliases de `SurfaceColorBake`/`SurfaceColorMode`.
- `OceanWaterVertexAlpha` number: alpha usado no `EditableMesh:AddColor` para vertices sem espuma. Padrao `0.5`.
- `OceanFoamVertexAlpha` number: alpha usado no `EditableMesh:AddColor` para vertices com espuma cheia. Padrao `1`.
- `OceanFoamVertexBoost` number: multiplicador da mascara de espuma pintada nos vertices. Padrao `1.35`.
- `OceanFoamNoiseInfluence` number: influencia do recorte procedural usado para quebrar linhas perfeitas de foam nos vertices e no `EditableImage`. Padrao `0.72`; `0` nao recorta, `1` usa todo o pattern.
- `OceanRuntimeSurfaceColorEnabled` boolean: compatibilidade antiga; quando definido nas opcoes, `true` equivale a `OceanSurfaceColorBake=false`.
- `OceanTransparency` number: transparencia do `MeshPart`; `OceanWaterVertexAlpha` controla o alpha das cores do `EditableMesh`.
- `OceanReflectance` number: reflexo do MeshPart.
- `OceanWaterNormalEnabled` boolean: ativa um `EditableImage` animado como `NormalMap` dentro do `SurfaceAppearance`. Padrao `true`.
- `OceanWaterNormalResolution` number: resolucao do `EditableImage` de normal. Padrao `64`.
- `OceanWaterNormalStrength` number: intensidade da perturbacao de normal procedural/ondas. Padrao `0.9`.
- `OceanWaterNormalScale` number: escala em studs do detalhe de normal animado. Padrao `18`.
- `OceanWaterNormalSpeed` number: velocidade do detalhe de normal. Padrao `0.72`.
- `OceanWaterNormalUpdateInterval` number: intervalo alvo usado para pre-bakear o loop RGB da normal; em runtime o sistema apenas copia o frame pronto para o `NormalMap`. O bake e limitado a 240 frames por tile. Padrao `0.05`.
- `OceanFresnelEnabled` boolean: aplica alpha Fresnel por vertice usando `1 - abs(Normal:Dot(ViewDir))`. Padrao `true`.
- `OceanFresnelStrength` number: quanto o Fresnel multiplica o alpha da agua/foam pintado nos vertices. Padrao `0.72`.
- `OceanFresnelPower` number: curva do Fresnel; valores maiores seguram mais alpha ate a normal ficar bem lateral. Padrao `1.1`.
- `OceanHideSourceParts` boolean: esconde localmente os Parts fonte. Padrao `true`.
- `OceanEnableSeaSpray` boolean: ativa/desativa particulas simples de spray quando `OceanSeaSprayTextureId` esta configurado.
- `OceanCpuReadback` boolean: controle reservado no painel runtime para manter paridade visual com o painel Godot.
- `OceanPanelCameraFOV` number: FOV editado pelo painel.
- `OceanFoamTextureId` string: override opcional de `ColorMap` por AssetID no caminho por vertice/manual, por exemplo `rbxassetid://123`.
- `OceanFoamTextureFromVerticesEnabled` boolean: compatibilidade antiga; quando definido nas opcoes como `true`, seleciona `OceanSurfaceColorMode="PaintVertices"` se `OceanSurfaceColorMode` nao existir.
- `OceanFoamTextureResolution` number: resolucao do `EditableImage` usado pelos modos com `SurfaceAppearance`. Padrao `64`.
- `OceanFoamTextureUpdateInterval` number: intervalo de atualizacao usado apenas quando `OceanSurfaceColorBake=false`; no bake RGBA cada frame pronto e aplicado quando o frame do loop muda. Padrao `0.08`.
- `OceanFoamTextureTransparency` number: transparencia aplicada ao foam localizado do `FoamBuffer` antes da textura final. Nao afeta o foam de crista, que usa `OceanCrestFoamAlphaTop`. Padrao `0`.
- `OceanFoamTextureStudsPerTile` number: escala usada apenas pelo fallback procedural por vertices. Padrao `18`.
- `OceanFoamNoiseSize` number: resolucao logica do pattern procedural usado apenas no fallback por vertices. Padrao `128`.
- `OceanFoamNoiseSeed` number: seed do pattern procedural usado apenas no fallback por vertices. Padrao `1234`.
- `OceanSeaSprayTextureId` string: AssetID opcional para a textura de particula de spray. Use o upload de `GodotOceanWaves-main/assets/water/sea_spray.png`.
- `OceanSeaSprayRate` number: taxa maxima do spray por tile. Padrao `90`.

## Assets do Godot

O Roblox nao consegue usar diretamente arquivos locais como `res://assets/water/sea_spray.png`.
Suba a imagem no Roblox Studio e cole o AssetID no painel runtime ou em `Workspace.Water`.

No original:

- `sea_spray.png` e usado pelo shader/material de particulas de spray.
- A espuma da superficie nao vem dessa imagem. Ela vem do `foam_factor` calculado no shader e de `foam_noise_tex`, uma `NoiseTexture2D` procedural definida em `mat_water.tres`.

Neste port:

- A agua e o tint agora sao uma funcao so: `ColorBack = Color3.fromRGB(11, 42, 80)`, `ColorTop = Color3.fromRGB(31, 143, 128)`, `Gain = 0.5`. A altura da onda entra normalizada de `0..1`; `0` usa `ColorBack`, `1` usa `ColorTop`, e a posicao do gradiente e multiplicada pelo ganho.
- A malha fica com `MeshPart.Transparency = 0.02`; a agua e a espuma usam alpha por vertice/cor via `EditableMesh:AddColor` ou via `SurfaceAppearance`. Por padrao a agua chega a alpha `0.5` em profundidade cheia e fica quase invisivel em agua rasa usando o mesmo `DepthMap` raycastado que escala as ondas. A espuma usa alpha proprio de crista. Quando as cores por vertice estao disponiveis, o `MeshPart.Color` fica branco para nao tingir a espuma.
- A cor do foam vem sempre de `OceanFoamColor`; o gradiente verde da agua/tint nao entra na cor da espuma. `OceanFoamTextureTransparency` so reduz foam localizado, enquanto a crista usa `OceanCrestFoamAlphaBack/Top/Gain`.
- `OceanSurfaceColorBake=true` usa o min/max do loop bakeado de alturas para normalizar a onda durante o bake RGBA. Depois disso o runtime nao reamostra cor, espuma ou profundidade para a superficie visual.
- `SurfaceAppearance` escreve agua+foam no `ColorMap`; `FoamSurfaceAppearance` escreve apenas o foam no `ColorMap` e deixa a agua nos vertices; `PaintVertices` cria um `SurfaceAppearance` para o pipeline e deixa a cor nos vertices. Quando `OceanWaterNormalEnabled=true`, esse mesmo `SurfaceAppearance` tambem recebe um `NormalMap` animado por `EditableImage`.
- `OceanSeaSprayTextureId` ativa particulas de spray usando a textura enviada ao Roblox.

## Atributos por cascata

O painel edita tres cascatas independentes. Use o prefixo `OceanCascadeN`, onde `N` e `1`, `2` ou `3`.

- `OceanCascadeNTileLengthX` number
- `OceanCascadeNTileLengthY` number
- `OceanCascadeNDisplacementScale` number
- `OceanCascadeNNormalScale` number
- `OceanCascadeNWindSpeed` number
- `OceanCascadeNWindDirection` number
- `OceanCascadeNFetchLength` number
- `OceanCascadeNSwell` number
- `OceanCascadeNSpread` number
- `OceanCascadeNDetail` number
- `OceanCascadeNWhitecap` number
- `OceanCascadeNFoamAmount` number

## Atributos por Part

- `OceanResolution` number: sobrescreve a resolucao fixa para esse tile, desativando o calculo por `OceanVertexSpacing` nele.
- `OceanVertexSpacing` number: sobrescreve o espacamento por studs para esse tile.
- `OceanSurfaceOffset` number: altura local da superficie em relacao ao centro do Part. Padrao `part.Size.Y * 0.5`.
- `OceanHideSourcePart` boolean: sobrescreve o hide para esse Part.

## Notas do port

Roblox nao executa os compute/spatial shaders do projeto Godot. Esta versao troca a FFT em GPU por 8 Gerstner waves fixas, escolhidas com pesos JONSWAP/TMA e espalhamento direcional Hasselmann para preservar os mesmos parametros conceituais: vento, fetch, swell, spread, detail, choppiness e whitecap/foam. O espectro ainda e baked em buffers e pode rodar em `Actor` via Parallel Luau. Depois cada tile faz um segundo bake temporal completo: deslocamento local, altura consultada pela fisica e sinais visuais de crista com foam/tamanho de onda/alpha sao gravados por `OceanWaveLoopFrames`; no update normal esses sinais sao amostrados direto pela aparencia, sem passar pelo campo persistente, e a malha interpola frames para aplicar `EditableMesh:SetPosition`.

As tres cascatas padrao representam profundidade: oceano profundo usa ondas 200x200, displacement/normal 2 e vento 40; lago usa 80x80, displacement/normal 1 e vento 20; raso usa a configuracao anterior. O `DepthMap` decide por vertice qual cascade domina dentro do mesmo mesh. A profundidade, pesos de cascade, escala de onda, foam de praia/obstaculo e obstaculos sao raycast/baked na inicializacao do tile; depois o update so amostra mapas/buffers baratos para deixar praia rasa menor, mar profundo mais volumetrico e espuma localizada em praia, obstaculo, crista e impacto.

A interacao fisica visual segue o demo `Simulation`: `AddDrop`, `StepSimulation`, `UpdateNormals` e `MoveSphere`. O sistema de buoyancy e separado: ele usa `GetHeight`, `GetNormal` e `GetVelocity`, amostra 1/4/8 pontos por Part e aplica empuxo, damping e drag apenas em objetos fisicos nao anchored. O player usa uma boia vertical propria perto da superficie bakeada, entra em `Swimming` quando toca a faixa de onda e toca diretamente as animacoes `Animate.swim.Swim` e `Animate.swimidle.SwimIndle`/`SwimIdle` quando existirem. Objetos fisicos ainda usam um proxy de esfera na linha da agua para o `MoveSphere`, assim um player andando e um Part grande caindo geram deslocamento mesmo quando o centro do objeto esta acima da superficie. Splash, foam e area de ripple escalam por footprint, raio e velocidade vertical. O sinal oceanico de crista segue a ideia do `fft_unpack.glsl`, mas agora e amostrado direto como foam fino e tamanho de onda; o `FoamBuffer` fica para foam persistente de interacao, praia e obstaculo. A aparencia de profundidade/fresnel do shader foi aproximada com material, transparencia, reflectance, fog submerso e cor de face quando `EditableMesh:SetFaceColors` estiver disponivel.

Os tiles tambem usam LOD por distancia: o sistema rastreia todos os `BasePart` em `Workspace.Water`, mas so cria `EditableMesh` quando a camera entra em `OceanLoadDistance`; depois descarrega em `OceanUnloadDistance`. O LOD externo pode reconstruir o chunk inteiro em 96/64/32/16 vertices por eixo, e o culling de campo de visao pula apenas o update visual de chunks fora da tela. Tiles longe que continuam carregados atualizam com FPS menor e stride de vertices maior, entao menos vertices entram no update normal. A fisica e o foam local so entram nas distancias dedicadas; ondas interativas que saem do LOD proximo dissipam progressivamente com `OceanInteractiveLodDissipation`.

A malha usa `OceanVertexSpacing` para distribuir vertices por studs e alinha vertices internos a uma grade global baseada na posicao/orientacao do Part. Como o bake de ondas e sinal de crista usa posicao world e seed, dois oceanos colados com mesmo seed/spacing ficam sincronizados sem detectar vizinhos. As distancias de LOD sao em studs. Em Parts enormes, por exemplo `2000, 1, 2000`, o LOD visual e aplicado dentro do mesh por aneis concentricos centrados na camera: o sistema classifica vertices so quando a camera cruza `OceanLodRecenterDistance`, grava os indices em `buffer`, e no frame percorre apenas esse cache. LOD0 atualiza todos os vertices e foam completa, LOD1 usa `OceanMidLodVertexStep` e amostra o mesmo campo com escala reduzida, LOD2 usa `OceanFarLodVertexStep` sem foam, e o resto usa `OceanExtremeLodVertexStep`. A fisica e o foam dinamico usam janelas locais perto da camera, nao o Part inteiro.

Para funcionar em Studio/experiencia, o place precisa permitir as Mesh & Image APIs usadas por `AssetService:CreateEditableMesh`.
