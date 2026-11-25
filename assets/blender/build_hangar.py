# Hangar do aeroporto (Hangar): gera Hangar.glb, uma mesh por papel de cor, com avião e ferramentas dentro.
# Rodar: blender --background --factory-startup --python assets/blender/build_hangar.py -- <pasta de saída> [export] [vistas]
import math, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.dont_write_bytecode = True
sys.path.insert(0, HERE)
import kit as k
from kit import box, lerp, loft, prism_x, shape, tube

ARGS = sys.argv[sys.argv.index("--") + 1:]
OUT = ARGS[0]
k.setup({
    "PlaneBody": (228, 228, 236), "TowerBlue": (52, 102, 210), "TowerNavy": (34, 66, 152), "Window": (70, 190, 250),
    "Metal": (122, 124, 136), "Steel": (160, 162, 178), "ToyYellow": (250, 190, 40), "Cone": (255, 120, 30),
    "Cardboard": (232, 168, 80), "Light": (255, 236, 180), "Tire": (46, 46, 52),
})
lamp = k.mats["Light"].node_tree.nodes["Principled BSDF"]
lamp.inputs["Emission Color"].default_value = (1, .85, .55, 1)
lamp.inputs["Emission Strength"].default_value = 1.2


# polígono (x, z) puxado em y
def prism_y(role, poly, y0, y1, **kw):
    loft(role, [[(x, y, z) for x, z in poly] for y in (y0, y1)], **kw)


# placa deitada numa rampa do telhado: (x0, z0)-(x1, z1) é a linha da rampa, u = trecho dela, de y0 a y1
def on_slope(role, m, a, b, u0, u1, y0, y1, lift, thick, bevel=.03):
    dx, dz = b[0] - a[0], b[1] - a[1]
    n = math.hypot(dx, dz)
    nx, nz = (dz / n, -dx / n)
    if nz < 0:
        nx, nz = -nx, -nz
    poly = []
    for u, h in ((u0, lift - thick), (u1, lift - thick), (u1, lift), (u0, lift)):
        poly.append((m * (lerp(a[0], b[0], u) + nx * h), lerp(a[1], b[1], u) + nz * h))
    prism_y(role, poly, y0, y1, bevel=bevel)


def rrect(cx, cz, w, h, r, n=3):
    pts = []
    for sx, sz, a0 in ((1, 1, 0), (-1, 1, 90), (-1, -1, 180), (1, -1, 270)):
        for i in range(n + 1):
            a = math.radians(a0 + 90 * i / n)
            pts.append((cx + sx * (w / 2 - r) + r * math.cos(a), cz + sz * (h / 2 - r) + r * math.sin(a)))
    return pts


FRONT, BACK, FL = -8.3, 9.7, .45
k.begin()
# ---- piso: calçada em volta, pátio na frente, linhas amarelas
box("Steel", 0, .1, 0, 26.6, 21.8, .4, bevel=.1, seg=2)
box("Steel", 0, -8.4, 0, 18.6, 6.2, .42, bevel=.1)
box("Metal", 0, -.9, .3, 17.6, 20.6, FL - .3, bevel=.02)
for x, y, w, d in ((0, -7.3, 17.2, .34), (-4.4, .6, .34, 15.6), (4.4, .6, .34, 15.6), (0, 8.2, 9.1, .34), (0, -9.2, .34, 3.5)):
    box("ToyYellow", x, y, FL - .05, w, d, .09, bevel=0)

# ---- paredes
for m in (1, -1):
    box("PlaneBody", m * 10.75, 1.7, .4, .7, 16.0, 6.0, bevel=.05)
    box("TowerBlue", m * 10.75, 1.7, 2.35, .9, 16.05, 1.05, bevel=.04)
    box("TowerBlue", m * 10.75, 1.7, .4, .86, 16.05, .5, bevel=.04)
    # pilar da frente
    box("PlaneBody", m * 10.1, -7.7, .4, 3.0, 3.0, 6.0, bevel=.08, seg=2)
    box("TowerBlue", m * 10.1, -7.7, .4, 3.3, 3.3, .95, bevel=.09)
    box("TowerBlue", m * 10.1, -7.7, 2.35, 3.16, 3.16, 1.05, bevel=.07)
    box("Metal", m * 10.1, -9.25, 4.55, 1.3, .24, .72, bevel=.05)
    box("Light", m * 10.1, -9.36, 4.66, 1.04, .2, .5, bevel=.05)
    # pilar de trás
    box("PlaneBody", m * 10.1, 8.6, .4, 2.6, 2.6, 6.0, bevel=.08, seg=2)
    box("TowerBlue", m * 10.1, 8.6, 2.35, 2.76, 2.76, 1.05, bevel=.07)
    box("TowerBlue", m * 10.1, 8.6, .4, 2.9, 2.9, .95, bevel=.09)
    # cobertura lateral
    box("TowerBlue", m * 10.15, .55, 6.15, 4.1, 19.5, 1.55, top=.985, bevel=.12, seg=2)
    # janelas laterais (atravessam a parede)
    for y in (-4.2, -1.4, 2.6, 5.4):
        box("TowerNavy", m * 10.75, y, 3.75, .98, 1.95, 1.95, bevel=.05)
        box("Window", m * 10.75, y, 3.98, 1.1, 1.5, 1.5, bevel=0)
# costura e parede da frente (com o vão) e de trás
roof_in = [(10.4, 7.5), (9.2, 8.7), (4.2, 10.1), (2.2, 10.9)]
arch = [(8.4, .4), (8.4, 5.9), (6.9, 7.4)]
front = [(10.4, .4)] + roof_in + [(-x, z) for x, z in reversed(roof_in)] + [(-10.4, .4)] + [(-x, z) for x, z in arch] + list(reversed(arch))
shape("PlaneBody", [front], FRONT, .7, bevel=.04)
shape("PlaneBody", [[(10.6, .4)] + roof_in + [(-x, z) for x, z in reversed(roof_in)] + [(-10.6, .4)]], BACK - .6, .6, bevel=.04)
for m in (1, -1):
    box("Steel", m * 4.7, FRONT, 8.0, .08, .1, 1.95, bevel=0)
box("TowerBlue", 0, BACK - .1, 2.35, 18.6, .5, 1.05, bevel=.04)
for x in (-6, 0, 6):
    box("TowerNavy", x, BACK - .3, 4.3, 4.7, .8, 2.3, bevel=.05)
    for s in (-1.1, 1.1):
        box("Window", x + s, BACK - .3, 4.52, 2.0, .94, 1.86, bevel=0)
# arco azul do vão
half = [(8.65, 5.2), (8.65, 6.75), (7.3, 8.1)]
shape("TowerBlue", [half + [(-x, z) for x, z in reversed(half)] + [(-6.85, 7.0), (6.85, 7.0)]], FRONT - .5, 1.1, bevel=.06)
for x in (-4.6, 0, 4.6):
    box("Metal", x, FRONT - .5, 6.5, 2.3, .6, .6, bevel=.05)
    box("Light", x, FRONT - .72, 6.56, 2.0, .34, .46, bevel=.06)

# ---- telhado em degraus
P1 = [(11.0, 7.45), (9.5, 9.15), (4.1, 10.75), (4.1, 9.3), (8.9, 7.95), (9.4, 7.3)]
P2 = [(5.35, 10.0), (5.0, 11.15), (2.2, 12.0), (2.2, 10.5), (5.1, 9.75)]
for m in (1, -1):
    prism_y("TowerBlue", [(m * x, z) for x, z in P1], FRONT - .55, BACK + .35, bevel=.09, flat=True)
    prism_y("TowerBlue", [(m * x, z) for x, z in P2], FRONT - .75, BACK + .5, bevel=.09, flat=True)
    # claraboias: moldura e três vidros
    for a, b, u0, u1, y0 in ((P1[1], P1[2], .12, .74, -6.6), (P1[1], P1[2], .12, .74, 2.6), (P2[1], P2[2], .14, .86, -6.6), (P2[1], P2[2], .14, .86, 2.6)):
        on_slope("TowerNavy", m, a, b, u0, u1, y0, y0 + 5.4, .14, .3, bevel=.05)
        for i in range(3):
            g0 = y0 + .3 + i * 1.64
            on_slope("Window", m, a, b, u0 + .05, u1 - .05, g0, g0 + 1.5, .2, .2, bevel=0)
cap = [(-2.9, 10.9), (2.9, 10.9), (2.9, 12.35), (2.45, 12.75), (-2.45, 12.75), (-2.9, 12.35)]
prism_y("TowerBlue", cap, FRONT - 1.25, BACK + .7, bevel=.1, flat=True)
# placa do avião
box("PlaneBody", 0, FRONT - .25, 7.55, 5.0, 1.1, 3.5, bevel=.09, seg=2)
shape("TowerBlue", [rrect(0, 9.4, 3.9, 3.0, .4)], FRONT - .98, .3, bevel=.05)
icon = [(0, 1.45), (.2, 1.2), (.24, .5), (1.35, -.3), (1.35, -.62), (.24, -.22), (.18, -.95), (.55, -1.25), (.55, -1.5), (0, -1.32)]
icon = icon + [(-x, z) for x, z in reversed(icon[1:-1])]
c45, s45 = math.cos(math.radians(-45)), math.sin(math.radians(-45))
shape("PlaneBody", [[((x * c45 - z * s45) * .92, 9.36 + (x * s45 + z * c45) * .92) for x, z in icon]], FRONT - 1.1, .2, bevel=.02)

# ---- por dentro: colunas, porta, rodapé
for x in (-9.0, -3, 3, 9.0):
    box("TowerNavy", x, BACK - .85, FL, .75, .6, 8.2 if abs(x) < 5 else 6.4, bevel=.05)
    box("TowerNavy", x, BACK - .9, FL, 1.0, .75, .7, bevel=.05)
for m in (1, -1):
    for y in (-2.8, 4.0):
        box("TowerNavy", m * 10.0, y, FL, .8, .8, 5.9, bevel=.05)
box("TowerNavy", 7.0, BACK - .72, FL, 1.9, .3, 3.3, bevel=.04)
box("Steel", 6.35, BACK - .9, 1.9, .18, .2, .18, bevel=0)

# ---- avião pequeno, de frente para a saída
PX, PY, PZ = .4, 2.1, 2.75


def hull(y, r, zc, flatz=1.0):
    return [(PX + r * math.cos(2 * math.pi * (i + .5) / 10), PY + y, PZ + zc + r * flatz * math.sin(2 * math.pi * (i + .5) / 10)) for i in range(10)]


loft("PlaneBody", [hull(-5.6, .22, -.35), hull(-5.35, .62, -.28), hull(-4.6, 1.02, -.12), hull(-3.6, 1.25, 0), hull(2.4, 1.25, 0), hull(4.4, .85, .3), hull(5.6, .4, .6)], bevel=0, smooth=True)
loft("TowerBlue", [[(PX + x, PY + y, PZ + z) for x, z in ((-w, -.78), (w, -.78), (w * .62, -1.3), (-w * .62, -1.3))] for y, w in ((-4.2, .75), (-3.2, 1.0), (2.0, 1.0), (3.2, .7))], bevel=.05)
for m in (1, -1):
    for i in range(5):
        box("TowerNavy", PX + m * 1.17, PY - 2.0 + i * .85, PZ + .1, .22, .45, .6, bevel=.04)
    # para-brisa
    def skin(y, deg, lift):
        f = [(-5.35, .62, -.28), (-4.6, 1.02, -.12), (-3.6, 1.25, 0)]
        a, b = (f[0], f[1]) if y < -4.6 else (f[1], f[2])
        t = (y - a[0]) / (b[0] - a[0])
        r, zc, ang = lerp(a[1], b[1], t) + lift, lerp(a[2], b[2], t), math.radians(deg)
        return (PX + m * r * math.cos(ang), PY + y, PZ + zc + r * math.sin(ang))

    for pane in (((-4.72, 88), (-4.62, 54), (-3.62, 54), (-3.75, 88)), ((-4.62, 54), (-4.4, 22), (-3.62, 24), (-3.62, 54))):
        loft("TowerNavy", [[skin(y, d, h) for y, d in pane] for h in (-.2, .08)], bevel=0, flat=True)
    # asa, ponta, motor, estabilizador
    for role, x0, x1, t in (("TowerBlue", .9, 2.3, .34), ("Steel", 2.25, 5.7, .26)):
        rings = []
        for x in (x0, x1):
            f = (x - .9) / 4.8
            a, b, z = PY + lerp(-1.4, .9, f), PY + lerp(1.5, 2.1, f), PZ - .5 + f * .35
            rings.append([(PX + m * x, a, z), (PX + m * x, b, z), (PX + m * x, b, z + t), (PX + m * x, a, z + t)])
        loft(role, rings, bevel=.05)
    box("Steel", PX + m * 5.65, PY + 1.6, PZ - .1, .26, 1.2, 1.0, top=.7, bevel=.05)
    ex, ez = PX + m * 3.0, PZ - 1.15

    def ring(y, r, n=12):
        return [(ex + r * math.cos(2 * math.pi * i / n), PY + y, ez + r * math.sin(2 * math.pi * i / n)) for i in range(n)]

    loft("PlaneBody", [ring(1.0, .5), ring(-.6, .8), ring(-1.5, .82), ring(-1.75, .72), ring(-1.75, .58), ring(-1.4, .54)], bevel=0, smooth=False)
    loft("Tire", [ring(-1.42, .55), ring(-1.3, .55)], bevel=0)
    loft("Steel", [ring(-1.42, .24), ring(-1.68, .1)], bevel=0)
    box("PlaneBody", ex, PY - .2, ez + .5, .3, 1.3, .6, bevel=.04)
    rings = []
    for x in (.3, 2.5):
        f = (x - .3) / 2.2
        a, b = PY + lerp(4.1, 5.1, f), PY + lerp(5.5, 5.8, f)
        rings.append([(PX + m * x, a, PZ + .6), (PX + m * x, b, PZ + .6), (PX + m * x, b, PZ + .82), (PX + m * x, a, PZ + .82)])
    loft("TowerNavy", rings, bevel=.04)
prism_x("TowerNavy", [(PY + 3.2, PZ + .9), (PY + 5.5, PZ + .9), (PY + 6.0, PZ + 3.4), (PY + 5.2, PZ + 3.4)], PX - .18, PX + .18, bevel=.06)


def wheels(x, y, top):
    box("Steel", x, y, FL + .35, .24, .24, top - FL - .35, bevel=0)
    for s in (1, -1):
        loft("Tire", [[(x + s * q, y + .42 * math.cos(2 * math.pi * (i + .5) / 10), FL + .4 + .42 * math.sin(2 * math.pi * (i + .5) / 10)) for i in range(10)] for q in (.12, .42)], bevel=.05)


wheels(PX, PY - 4.0, PZ - .8)
for m in (1, -1):
    wheels(PX + m * 1.2, PY + .9, PZ - .6)

# ---- bancada e caixas (esquerda), estante e escada (direita), cones
X, Y = -6.9, -5.6
box("TowerBlue", X, Y, FL + .3, 3.0, 1.7, 1.35, bevel=.06)
box("TowerNavy", X, Y, FL + 1.6, 3.2, 1.9, .22, bevel=.05)
for s in (1, -1):
    for z in (.45, 1.02):
        box("TowerNavy", X + s * .72, Y - .87, FL + z, 1.2, .12, .48, bevel=.03)
        box("Steel", X + s * .72, Y - .95, FL + z + .26, .7, .1, .1, bevel=0)
    for t in (1, -1):
        box("Tire", X + s * 1.2, Y + t * .6, FL, .3, .3, .34, bevel=.04)
box("Metal", X - .45, Y, FL + 1.8, 1.6, 1.4, 1.0, bevel=.05)
box("Steel", X - .45, Y, FL + 2.78, 1.66, 1.46, .9, bevel=.06)
box("Cardboard", X + .95, Y - .1, FL + 1.8, 1.05, 1.05, 1.05, bevel=.06)
for x, y, z, s, role in ((-8.3, 7.4, FL, 1.7, "TowerBlue"), (-6.4, 7.5, FL, 1.6, "Cardboard"), (-6.5, 7.5, FL + 1.58, 1.2, "Cardboard"), (-8.3, 7.4, FL + 1.68, 1.2, "Steel")):
    box(role, x, y, z, s, s, s, bevel=.07)
SX, SY = 8.5, 1.0
for dx in (-.8, .8):
    for dy in (-1.6, 1.6):
        box("Metal", SX + dx, SY + dy, FL, .22, .22, 4.4, bevel=0)
for z in (.35, 1.75, 3.15, 4.3):
    box("Metal", SX, SY, FL + z, 1.9, 3.5, .18, bevel=.03)
for y, z, s, role in ((-.8, .5, 1.0, "Steel"), (.7, .5, 1.0, "Cardboard"), (-.75, 1.9, .95, "TowerBlue"), (.6, 1.9, 1.0, "TowerBlue"), (-.8, 3.3, .85, "Steel"), (.6, 3.3, .9, "Cardboard")):
    box(role, SX - .1, SY + y, FL + z, s, s, s, bevel=.05)
# escada de embarque
LX, LY = 5.9, -4.4
for s in (1, -1):
    tube("ToyYellow", [(LX + s * .75, LY - 1.4, FL + .4), (LX + s * .75, LY + .5, FL + 2.0)], [.13, .13], n=6, bevel=0)
    tube("ToyYellow", [(LX + s * .75, LY - 1.4, FL + 1.35), (LX + s * .75, LY + .5, FL + 2.95), (LX + s * .75, LY + 1.5, FL + 2.95)], [.1, .1, .1], n=6, bevel=0)
    for y, z0, z1 in ((-1.4, .3, 1.35), (.5, 0, 2.95), (1.5, 0, 2.95)):
        box("ToyYellow", LX + s * .75, LY + y, FL + z0, .2, .2, z1 - z0, bevel=0)
    for y in (-1.3, 1.4):
        box("Tire", LX + s * .75, LY + y, FL, .26, .4, .4, bevel=.05)
for i in range(4):
    box("ToyYellow", LX, LY - 1.15 + i * .46, FL + .5 + i * .4, 1.5, .44, .14, bevel=0)
box("ToyYellow", LX, LY + 1.0, FL + 2.0, 1.6, 1.2, .16, bevel=.03)
for x, y in ((-6.9, -8.6), (7.6, -8.7)):
    box("Cone", x, y, FL - .02, .95, .95, .16, bevel=.04)
    loft("Cone", [[(x + r * math.cos(2 * math.pi * i / 8), y + r * math.sin(2 * math.pi * i / 8), FL + z) for i in range(8)] for r, z in ((.36, .1), (.1, 1.2))], bevel=0)
    loft("PlaneBody", [[(x + r * math.cos(2 * math.pi * i / 8), y + r * math.sin(2 * math.pi * i / 8), FL + z) for i in range(8)] for r, z in ((.3, .5), (.22, .8))], bevel=0)

# ---- balizas do lado de fora
for x, y in ((-12.5, -9.6), (12.5, -9.6), (-12.5, 5.5), (12.5, 5.5)):
    box("Tire", x, y, .35, .72, .72, 1.75, bevel=.06)
    box("Light", x, y, 2.05, .8, .8, .85, bevel=.1)

meshes = k.finish("Hangar")
if "export" in ARGS:
    k.export(meshes, os.path.join(HERE, "Hangar.glb"))

k.stage((90, 226, 60), (1536, 1024))
which = [a for a in ARGS[1:] if a != "export"] or ["frente"]
VIEWS = {"frente": ((-17, -45, 20), (.6, 0, 5)), "reto": ((4, -44, 9), (0, 0, 5.2)), "tras": ((26, 40, 24), (0, 0, 5)), "cima": ((-24, -22, 34), (0, 0, 5))}
for w in which:
    k.shot(OUT + f"/hangar_{w}.png", *VIEWS[w])
