# Posto de gasolina (GasStation): gera GasStation.glb, uma mesh por papel de cor.
# Rodar: blender --background --factory-startup --python assets/blender/build_station.py -- <pasta de saída> [export] [vistas]
import math, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.dont_write_bytecode = True
sys.path.insert(0, HERE)
import kit as k
from kit import box, loft, shape, tube
from mathutils import Vector

ARGS = sys.argv[sys.argv.index("--") + 1:]
OUT = ARGS[0]
k.setup({
    "PlaneBody": (232, 232, 238), "PlaneFlap": (196, 200, 216), "Steel": (160, 164, 184), "ToyRed": (222, 28, 40),
    "Window": (64, 174, 240), "Glass": (150, 214, 250), "ToyDark": (66, 76, 104), "Light": (255, 236, 180),
    "ToyYellow": (250, 206, 30), "Canopy": (84, 176, 40),
})
lamp = k.mats["Light"].node_tree.nodes["Principled BSDF"]
lamp.inputs["Emission Color"].default_value = (1, .8, .45, 1)
lamp.inputs["Emission Strength"].default_value = 1.2


# retângulo de cantos redondos (w x d) na altura z, com recuo
def rr(w, d, r, z, inset=0.0, y=0.0, n=4):
    w, d, r = w - inset * 2, d - inset * 2, max(r - inset, .12)
    pts = []
    for sx, sy, a0 in ((1, 1, 0), (-1, 1, 90), (-1, -1, 180), (1, -1, 270)):
        for i in range(n + 1):
            a = math.radians(a0 + 90 * i / n)
            pts.append((sx * (w / 2 - r) + r * math.cos(a), y + sy * (d / 2 - r) + r * math.sin(a), z))
    return pts


# polígono com os cantos arredondados
def round_poly(pts, r, n=3):
    out = []
    for i, p in enumerate(pts):
        p = Vector(p)
        a, b = Vector(pts[i - 1]) - p, Vector(pts[(i + 1) % len(pts)]) - p
        q = min(r, a.length * .45, b.length * .45)
        s, e = p + a.normalized() * q, p + b.normalized() * q
        for j in range(n + 1):
            t = j / n
            v = s * (1 - t) ** 2 + p * 2 * t * (1 - t) + e * t ** 2
            out.append((v.x, v.y))
    return out


# faixa pintada no chão ao longo de um caminho
def ribbon(role, path, half, z0, z1):
    side = []
    for i, p in enumerate(path):
        d = (Vector(path[min(i + 1, len(path) - 1)]) - Vector(path[max(i - 1, 0)])).normalized()
        side.append(Vector((-d.y, d.x)) * half)
    poly = [tuple(Vector(p) + s) for p, s in zip(path, side)] + [tuple(Vector(p) - s) for p, s in reversed(list(zip(path, side)))]
    loft(role, [[(x, y, z) for x, y in poly] for z in (z0, z1)], bevel=0)


# janela na parede: moldura, vidro e reflexos inclinados. face = y da parede (frente) ou x (lado)
def window(cx, cz, w, h, y, m=-1, shine=True):
    box("ToyDark", cx, y, cz - h / 2, w, .36, h, bevel=.06)
    box("Window", cx, y + m * .1, cz - h / 2 + .2, w - .4, .28, h - .4, bevel=0)
    if shine:
        ih = h / 2 - .22
        for x0, wd in ((-.26, .34), (-.1, .12), (.2, .42), (.36, .12)):
            a = cx + x0 * (w - 1.2)
            s = ih * .62
            poly = [(a - s, cz - ih), (a - s + wd, cz - ih), (a + s + wd, cz + ih), (a + s, cz + ih)]
            loft("Glass", [[(x, yy, z) for x, z in poly] for yy in (y + m * .2, y + m * .27)], bevel=0)


k.begin()
F = .62  # altura do piso
# ---- piso
loft("PlaneFlap", [rr(23, 16.8, 1.7, 0), rr(23, 16.8, 1.7, .45), rr(23, 16.8, 1.7, .6, .16)], bevel=0)
loft("Steel", [rr(20.8, 14.6, 1.0, .4), rr(20.8, 14.6, 1.0, F)], bevel=0)
arc = [(-9.0 + .9 * math.cos(math.radians(a)), -5.7 + .9 * math.sin(math.radians(a))) for a in range(180, 271, 18)]
ribbon("ToyRed", [(-9.9, 6.6)] + arc + [(9.8, -6.6)], .17, F - .05, F + .06)

# ---- loja
X0, X1, Y0, Y1 = -10.0, 6.4, 1.0, 7.5
CX, CY, W, D = (X0 + X1) / 2, (Y0 + Y1) / 2, X1 - X0, Y1 - Y0
box("PlaneBody", CX, CY, F - .1, W, D, 7.5, bevel=.16, seg=2)
box("ToyRed", CX, CY, F - .1, W + .22, D + .22, 1.25, bevel=.12, seg=2)
window(-6.9, 3.55, 3.6, 2.5, Y0)
window(3.35, 3.65, 4.8, 2.6, Y0)
for x in (-6.2, 2.6):
    window(x, 3.9, 4.2, 2.4, Y1, m=1, shine=False)
# porta
DX = -2.7
box("PlaneBody", DX, Y0 - .1, F - .1, 4.6, .7, 4.7, bevel=.08)
box("ToyDark", DX, Y0 - .3, F, 3.5, .5, 3.75, bevel=.06)
for s in (1, -1):
    box("Window", DX + s * .82, Y0 - .44, F + .22, 1.36, .34, 3.3, bevel=0)
    box("PlaneBody", DX + s * .24, Y0 - .68, F + 1.35, .18, .2, .7, bevel=.05)
    for a, wd in ((-.28, .26), (.08, .1)):
        poly = [(DX + s * .82 + a - .22, F + .5), (DX + s * .82 + a - .22 + wd, F + .5), (DX + s * .82 + a + .3 + wd, F + 3.2), (DX + s * .82 + a + .3, F + 3.2)]
        loft("Glass", [[(x, y, z) for x, z in poly] for y in (Y0 - .58, Y0 - .66)], bevel=0)
prof = round_poly([(-2.75, 4.55 + F), (2.75, 4.55 + F), (2.55, 5.75 + F), (-2.55, 5.75 + F)], .55, 4)
loft("ToyRed", [[(DX + x, y, z) for x, z in prof] for y in (Y0 + .1, Y0 - 1.35)], bevel=.1, seg=2)
box("Light", DX, Y0 - .95, F + 4.36, 2.4, .62, .24, bevel=.06)
box("PlaneFlap", DX, Y0 - 1.3, F - .1, 5.4, 2.6, .4, bevel=.12, seg=2)
box("ToyYellow", DX, Y0 - 1.6, F + .25, 3.6, 1.1, .1, bevel=.02)
# luzes da parede
for x in (-9.2, .25):
    box("ToyDark", x, Y0 - .12, F + 2.5, .78, .36, 1.15, bevel=.1)
    box("Light", x, Y0 - .24, F + 2.64, .5, .32, .86, bevel=.08)
# floreira
box("PlaneBody", -7.3, Y0 - 1.1, F - .05, 4.5, 1.5, 1.0, bevel=.12, seg=2)
for i in range(4):
    box("Canopy", -8.85 + i * 1.03, Y0 - 1.1, F + .75, .98, 1.1, 1.0 + (.12 if i % 2 else 0), bevel=.14, seg=2)

# ---- colunas
for m in (1, -1):
    box("PlaneBody", m * 8.0, -4.4, F - .1, 2.5, 2.3, 1.2, bevel=.16, seg=2)
    box("ToyRed", m * 8.0, -4.4, F + 1.0, 1.75, 1.75, .75, bevel=.06)
    box("PlaneFlap", m * 8.0, -4.4, F + 1.6, 1.6, 1.6, 5.9, bevel=.06)

# ---- cobertura
RW, RD, RR = 22.4, 16.0, 2.0
loft("PlaneFlap", [rr(RW, RD, RR, 7.75, 1.0), rr(RW, RD, RR, 8.0, .55), rr(RW, RD, RR, 8.35, .1)], bevel=0)
loft("ToyRed", [rr(RW, RD, RR, 8.28, .12), rr(RW, RD, RR, 8.4, -.08), rr(RW, RD, RR, 9.4, -.08), rr(RW, RD, RR, 9.5, .1)], bevel=0)
loft("PlaneBody", [rr(RW, RD, RR, 9.4, .05), rr(RW, RD, RR, 10.25, .05), rr(RW, RD, RR, 10.48, .25), rr(RW, RD, RR, 10.48, 1.45), rr(RW, RD, RR, 10.1, 1.65)], bevel=0)
loft("PlaneFlap", [rr(RW, RD, RR, 10.0, 1.62), rr(RW, RD, RR, 10.14, 1.62)], bevel=0)


# lâmpada na quina de baixo da cobertura (inclinada)
def lamp_at(x, y, ang):
    c, s = math.cos(ang), math.sin(ang)
    for role, w, o in (("PlaneFlap", .85, 0), ("Light", .68, -.07)):
        rings = []
        for lift in (.12, -.06):
            ring = []
            for a, b in ((-w, -.02), (w, -.02), (w, .6), (-w, .6)):
                f = .0 if role == "PlaneFlap" else .08
                bb = b + (f if b < .3 else -f)
                px, py, pz = a, -bb, 7.83 + bb * .72 + lift * .8 + o
                ring.append((x + px * c - py * s, y + px * s + py * c, pz))
            rings.append(ring)
        loft(role, rings, bevel=.03)


for x in (-8.4, -4.2, 0, 4.2, 8.4):
    lamp_at(x, -RD / 2 + .72, 0)
    lamp_at(x, RD / 2 - .72, math.pi)
for y in (-4.2, 4.2):
    lamp_at(RW / 2 - .72, y, math.pi / 2)
    lamp_at(-RW / 2 + .72, y, -math.pi / 2)

# ---- letreiro
sign = [(-3.6, 9.5), (3.6, 9.5), (2.75, 11.2), (2.15, 12.75), (-2.15, 12.75), (-2.75, 11.2)]
shape("PlaneBody", [round_poly(sign, .8, 4)], -RD / 2 - .08, 1.5, bevel=.1)
shape("ToyRed", [round_poly([(-2.85, 9.75), (2.85, 9.75), (2.3, 11.15), (1.85, 12.35), (-1.85, 12.35), (-2.3, 11.15)], .5, 4)], -RD / 2 - .2, .3, bevel=.05)
IY = -RD / 2 - .3
shape("PlaneBody", [round_poly([(-.8, 10.2), (.42, 10.2), (.42, 11.95), (.25, 12.1), (-.63, 12.1), (-.8, 11.95)], .12, 2),
                    round_poly([(-.55, 11.3), (.17, 11.3), (.17, 11.85), (-.55, 11.85)], .06, 2)], IY, .2, bevel=.03)
shape("PlaneBody", [round_poly([(-.98, 9.98), (.6, 9.98), (.6, 10.2), (-.98, 10.2)], .06, 2)], IY, .2, bevel=.03)
hose = [(.4, 11.05), (.62, 11.05), (.68, 10.85), (.68, 10.5), (.8, 10.36), (.98, 10.4), (1.06, 10.6), (1.06, 11.3), (.98, 11.6), (.72, 11.85), (.55, 11.95)]
tube("PlaneBody", [(x, IY + .1, z) for x, z in hose], [.1] * 8 + [.15, .13, .1], n=6, bevel=0)


# ---- bombas
def pump(x, y):
    loft("PlaneFlap", [rr(3.3, 2.5, .4, F + .3, 0, y), rr(3.3, 2.5, .4, F + .48, 0, y), rr(3.3, 2.5, .4, F + .56, .08, y)], bevel=0)
    loft("ToyDark", [rr(3.2, 2.4, .4, F - .05, 0, y), rr(3.2, 2.4, .4, F + .32, 0, y)], bevel=0)
    for o in (k.parts["PlaneFlap"][-1], k.parts["ToyDark"][-1]):
        for v in o.data.vertices:
            v.co.x += x
    box("ToyRed", x + .1, y, F + .5, 2.0, 1.5, 2.6, bevel=.1, seg=2)
    box("PlaneBody", x + .1, y, F + 3.0, 2.45, 1.95, 1.0, bevel=.2, seg=2)
    for m in (-1, 1):
        box("PlaneFlap", x + .3, y + m * .74, F + 1.75, 1.2, .12, 1.0, bevel=.03)
        box("Window", x + .3, y + m * .78, F + 1.83, 1.04, .12, .84, bevel=0)
    box("ToyDark", x - 1.02, y, F + .95, .4, 1.1, 1.75, bevel=.08)
    box("PlaneFlap", x - 1.3, y, F + 2.1, .3, .34, .55, bevel=.08)
    tube("ToyDark", [(x - 1.3, y - .1, F + 2.2), (x - 1.45, y - .45, F + 1.9), (x - 1.45, y - .55, F + 1.2), (x - 1.35, y - .35, F + .85), (x - 1.2, y, F + 1.05)], [.1] * 5, n=6, bevel=0)


pump(.2, -4.5)
pump(4.2, -4.5)

meshes = k.finish("GasStation")
if "export" in ARGS:
    k.export(meshes, os.path.join(HERE, "GasStation.glb"))

k.stage((100, 226, 66), (1448, 1086))
which = [a for a in ARGS[1:] if a != "export"] or ["frente"]
VIEWS = {"frente": ((-17, -42, 24), (-.3, 0, 4.6)), "reto": ((2, -42, 8), (0, 0, 5.2)), "tras": ((24, 38, 22), (0, 0, 5))}
for w in which:
    k.shot(OUT + f"/posto_{w}.png", *VIEWS[w])
