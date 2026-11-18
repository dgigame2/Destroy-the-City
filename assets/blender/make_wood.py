# Textura de madeira discreta para as placas do lobby: quase branca (a cor vem da peça, que multiplica a
# textura), com veios finos e suaves na horizontal e um relevo bem leve. Emenda nos 4 lados.
# Vira o MaterialVariant "SignWoodGrain" no Studio (base Wood, ColorMap + NormalMap).
# Uso: blender -b --factory-startup --python assets/blender/make_wood.py
# Saída: assets/blender/SignWoodGrain.png e SignWoodGrainNormal.png (512x512)

import bpy
import math
import os

import numpy as np

OUT = os.path.dirname(os.path.abspath(__file__))
N = 512
rng = np.random.default_rng(5)
f = np.fft.fftfreq(N)
fx, fy = np.meshgrid(f, f)


def noise(sx, sy):
    # ruído periódico esticado: sx/sy = suavidade em x e em y (veio comprido na horizontal)
    white = rng.standard_normal((N, N))
    k = np.exp(-(fx * fx) * sx * sx - (fy * fy) * sy * sy)
    out = np.real(np.fft.ifft2(np.fft.fft2(white) * k))
    return (out - out.mean()) / (out.std() + 1e-9)


ys, xs = np.mgrid[0:N, 0:N]
v = ys / N
warp = noise(60, 12) * 0.012
# veios: listras finas na horizontal (12 por tile), entortadas pelo ruído
lines = np.sin((v + warp) * math.tau * 12) * 0.5 + 0.5
lines = lines**6  # finas
fine = noise(200, 3)  # fibras compridas e finas
patch = noise(30, 30)  # manchas grandes bem suaves

shade = 0.93 - 0.07 * lines + 0.025 * fine + 0.02 * patch
shade = np.clip(shade, 0, 1)
# leve tom quente para não ficar acinzentado
color = np.stack([shade, shade * 0.985, shade * 0.96], axis=2)


def save(name, rgb):
    img = bpy.data.images.new(name, N, N, alpha=False)
    rgba = np.ones((N, N, 4), dtype=np.float32)
    rgba[:, :, :3] = rgb
    img.pixels = rgba.ravel()
    img.filepath_raw = os.path.join(OUT, name + ".png")
    img.file_format = "PNG"
    img.save()


save("SignWoodGrain", color)

height = -lines * 0.6 + fine * 0.08
strength = 1.2
dx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * strength
dy = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * strength
nx, ny, nz = -dx, -dy, np.ones_like(dx)
ln = np.sqrt(nx * nx + ny * ny + nz * nz)
save("SignWoodGrainNormal", np.stack([nx / ln, ny / ln, nz / ln], axis=2) * 0.5 + 0.5)
print("SignWoodGrain pronto")
