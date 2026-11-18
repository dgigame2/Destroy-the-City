# Textura de grama estilo cartoon das prints de referência do lobby: verde vivo quase liso, com muitos
# fiozinhos finos de grama (uns mais claros, outros mais escuros), manchas bem suaves e alguns trevinhos.
# Emenda nos 4 lados. Vira o MaterialVariant "LobbyGrassToon" no Studio (ColorMap + NormalMap, base Grass).
# Uso: blender -b --factory-startup --python assets/blender/make_grass.py
# Saída: assets/blender/LobbyGrassToon.png e LobbyGrassToonNormal.png (1024x1024)

import bpy
import math
import os
import random

import numpy as np

OUT = os.path.dirname(os.path.abspath(__file__))
N = 1024
BLADES = 26000  # fiozinhos de grama
CLOVERS = 70  # trevinhos (3 folhas redondas)
random.seed(21)
rng = np.random.default_rng(21)

f = np.fft.fftfreq(N)
fx, fy = np.meshgrid(f, f)


def smooth_noise(scale):
    # ruído periódico (emenda): ruído branco filtrado no domínio da frequência
    white = rng.standard_normal((N, N))
    k = np.exp(-(fx * fx + fy * fy) * (scale * scale))
    out = np.real(np.fft.ifft2(np.fft.fft2(white) * k))
    return (out - out.mean()) / (out.std() + 1e-9)


def blur(mask, radius):
    k = np.exp(-(fx * fx + fy * fy) * (radius * radius) * 20)
    return np.real(np.fft.ifft2(np.fft.fft2(mask) * k))


# cores (sRGB 0-1): verde da referência (não neon) e tons dos fios
base = np.array([0.33, 0.66, 0.17])
dark = np.array([0.24, 0.52, 0.12])
light = np.array([0.47, 0.78, 0.25])

patch = smooth_noise(60) * 0.6 + smooth_noise(160) * 0.4
t = np.clip(0.5 + 0.18 * patch, 0, 1)[:, :, None]
color = base * (0.9 + 0.2 * t)

light_mask = np.zeros((N, N))
dark_mask = np.zeros((N, N))
height = np.zeros((N, N))


def line(mask, x0, y0, x1, y1, value, hmask=None, hval=0.0):
    steps = int(max(abs(x1 - x0), abs(y1 - y0)) * 2) + 1
    for s in range(steps + 1):
        p = s / steps
        xi = int(x0 + (x1 - x0) * p) % N
        yi = int(y0 + (y1 - y0) * p) % N
        mask[yi, xi] = max(mask[yi, xi], value * (0.5 + 0.5 * p))
        if hmask is not None:
            hmask[yi, xi] = max(hmask[yi, xi], hval * p)


# fiozinhos: retos e finos (1 px), quase em pé, mais claros na ponta; uns escuros entre eles
for _ in range(BLADES):
    x, y = random.uniform(0, N), random.uniform(0, N)
    length = random.uniform(6, 14)
    ang = -math.pi / 2 + random.uniform(-0.45, 0.45)
    x1, y1 = x + math.cos(ang) * length, y + math.sin(ang) * length
    if random.random() < 0.6:
        line(light_mask, x, y, x1, y1, random.uniform(0.5, 1.0), height, 1.0)
    else:
        line(dark_mask, x, y, x1, y1, random.uniform(0.5, 1.0))

# trevinhos: 3 folhinhas redondas mais escuras, espalhados
yy, xx = np.mgrid[0:N, 0:N]
clover = np.zeros((N, N))
for _ in range(CLOVERS):
    cx, cy = random.uniform(0, N), random.uniform(0, N)
    rot = random.uniform(0, math.tau)
    for k in range(3):
        a = rot + k * math.tau / 3
        lx, ly = cx + math.cos(a) * 4.5, cy + math.sin(a) * 4.5
        dx = np.minimum(np.abs(xx - lx), N - np.abs(xx - lx))
        dy = np.minimum(np.abs(yy - ly), N - np.abs(yy - ly))
        clover = np.maximum(clover, np.clip(1.3 - np.hypot(dx, dy) / 4.0, 0, 1))

light_mask = np.clip(blur(light_mask, 0.25) * 1.6, 0, 1)
dark_mask = np.clip(blur(dark_mask, 0.25) * 1.6, 0, 1)
clover = np.clip(clover, 0, 1)
color = color * (1 - 0.55 * light_mask[:, :, None]) + light * (0.55 * light_mask[:, :, None])
color = color * (1 - 0.5 * dark_mask[:, :, None]) + dark * (0.5 * dark_mask[:, :, None])
color = color * (1 - 0.6 * clover[:, :, None]) + np.array([0.28, 0.6, 0.15]) * (0.6 * clover[:, :, None])
color = np.clip(color, 0, 1)
height = blur(height, 0.3) * 0.5 + clover * 0.4 + 0.05 * patch


def save(name, rgb):
    img = bpy.data.images.new(name, N, N, alpha=False)
    rgba = np.ones((N, N, 4), dtype=np.float32)
    rgba[:, :, :3] = rgb
    img.pixels = rgba.ravel()
    img.filepath_raw = os.path.join(OUT, name + ".png")
    img.file_format = "PNG"
    img.save()


save("LobbyGrassToon", color)

strength = 1.5  # relevo fraco: a grama da referência é quase lisa
dx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * strength
dy = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * strength
nx, ny, nz = -dx, -dy, np.ones_like(dx)
ln = np.sqrt(nx * nx + ny * ny + nz * nz)
normal = np.stack([nx / ln, ny / ln, nz / ln], axis=2) * 0.5 + 0.5
save("LobbyGrassToonNormal", normal)
print("LobbyGrassToon pronto")
