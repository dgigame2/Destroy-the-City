# Textura de lajotas (pedras cinza-claras irregulares, rejunte fundo) que emenda nos 4 lados, com normal map
# para dar relevo (as pedras são "almofadas" e o rejunte fica mais baixo). Vira o MaterialVariant
# "LobbyFlagstone" no Studio (ColorMap + NormalMap).
# Uso: blender -b --factory-startup --python assets/blender/make_flagstone.py
# Saída: assets/blender/LobbyFlagstone.png e LobbyFlagstoneNormal.png (512x512)

import bpy
import math
import os
import random

import numpy as np

OUT = os.path.dirname(os.path.abspath(__file__))
N = 512
CELLS = 150  # pedras na textura (mais = pedras menores)
GROUT = 0.0035  # meia largura do rejunte (em fração da textura)
ROUND = 0.012  # quanto da borda da pedra é arredondada
random.seed(7)

# pontos bem espalhados (sem dois quase no mesmo lugar, que viram pedras finas e manchas de rejunte)
MIN = 0.75 / math.sqrt(CELLS)
_pts = []
while len(_pts) < CELLS:
    p = (random.random(), random.random())
    if all(min(abs(p[0] - q[0]), 1 - abs(p[0] - q[0])) ** 2 + min(abs(p[1] - q[1]), 1 - abs(p[1] - q[1])) ** 2 > MIN * MIN for q in _pts):
        _pts.append(p)
pts = np.array(_pts)
tone = np.array([random.uniform(-0.07, 0.05) for _ in range(CELLS)])
tilt = np.array([[random.uniform(-0.25, 0.25), random.uniform(-0.25, 0.25)] for _ in range(CELLS)])

ys, xs = np.mgrid[0:N, 0:N]
u = (xs + 0.5) / N
v = (ys + 0.5) / N
# leve deformação para as pedras não ficarem retas demais
wu = u + 0.006 * np.sin(v * math.tau * 4) + 0.004 * np.sin(v * math.tau * 9 + 1)
wv = v + 0.006 * np.sin(u * math.tau * 4 + 2) + 0.004 * np.sin(u * math.tau * 7)
d1 = np.full((N, N), 9.0)
d2 = np.full((N, N), 9.0)
idx = np.zeros((N, N), dtype=int)
for i, (px, py) in enumerate(pts):
    for ox in (-1, 0, 1):  # 9 cópias de cada ponto: a textura emenda
        for oy in (-1, 0, 1):
            d = np.hypot(wu - (px + ox), wv - (py + oy))
            closer = d < d1
            d2 = np.where(closer, d1, np.minimum(d2, d))
            idx = np.where(closer, i, idx)
            d1 = np.where(closer, d, d1)
edge = (d2 - d1) / 2  # distância até a divisa entre pedras

# altura: 0 no rejunte, sobe arredondado na borda e fica quase plana no meio (com leve inclinação)
inside = np.clip((edge - GROUT) / ROUND, 0, 1)
height = np.sqrt(inside) * (0.85 + tone[idx])
height += inside * (tilt[idx, 0] * (u - pts[idx, 0]) + tilt[idx, 1] * (v - pts[idx, 1])) * 0.5
grain = 0.02 * np.sin(u * 140 + np.sin(v * 90) * 3) * np.sin(v * 120 + np.sin(u * 70) * 3)
height += grain * inside

# cor: pedra clara com variação, rejunte cinza, sombra perto do rejunte (dá volume)
base = np.array([0.82, 0.81, 0.78])
grout = np.array([0.52, 0.51, 0.49])
stone = base[None, None, :] + tone[idx][:, :, None]
stone *= (0.86 + 0.14 * np.clip(edge / (GROUT + ROUND * 1.5), 0, 1))[:, :, None]
mix = np.clip((edge - GROUT) / 0.0025, 0, 1)[:, :, None]
color = np.clip(grout * (1 - mix) + stone * mix, 0, 1)


def save(name, rgb):
    img = bpy.data.images.new(name, N, N, alpha=False)
    rgba = np.ones((N, N, 4), dtype=np.float32)
    rgba[:, :, :3] = rgb
    img.pixels = rgba.ravel()
    img.filepath_raw = os.path.join(OUT, name + ".png")
    img.file_format = "PNG"
    img.save()


save("LobbyFlagstone", color)

# normal map (OpenGL, Y para cima) a partir da altura; as bordas emendam (np.roll)
strength = 6.0
dx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * strength
dy = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * strength
nx, ny, nz = -dx, -dy, np.ones_like(dx)
ln = np.sqrt(nx * nx + ny * ny + nz * nz)
normal = np.stack([nx / ln, ny / ln, nz / ln], axis=2) * 0.5 + 0.5
save("LobbyFlagstoneNormal", normal)
print("LobbyFlagstone pronto")
