# Torre do aeroporto (ControlTower): gera ControlTower.glb, uma mesh por papel de cor.
# Rodar: blender --background --factory-startup --python assets/blender/build_tower.py -- <pasta de saída> [export] [vistas]
import math, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.dont_write_bytecode = True
sys.path.insert(0, HERE)
import kit as k
from kit import box, loft, tube
from mathutils import Vector

ARGS = sys.argv[sys.argv.index("--") + 1:]
OUT = ARGS[0]
k.setup({
    "PlaneBody": (228, 228, 236), "TowerBlue": (46, 96, 214), "TowerNavy": (20, 54, 152), "TowerRoof": (78, 140, 236),
    "TowerGlass": (64, 180, 250), "TruckCab": (0, 150, 250), "Light": (255, 236, 180), "PlaneFlap": (196, 206, 226),
})
glass = k.mats["TowerGlass"].node_tree.nodes["Principled BSDF"]
glass.inputs["Alpha"].default_value = .7
lamp = k.mats["Light"].node_tree.nodes["Principled BSDF"]
lamp.inputs["Emission Color"].default_value = (1, .85, .55, 1)
lamp.inputs["Emission Strength"].default_value = 1.2


# octógono com faces retas para a frente e os lados; a = do centro até a face
def octa(a, z, x=0.0, y=0.0):
    r = a / math.cos(math.radians(22.5))
    return [(x + r * math.cos(math.radians(22.5 + 45 * i)), y + r * math.sin(math.radians(22.5 + 45 * i)), z) for i in range(8)]


def stack(role, levels, x=0.0, y=0.0, **kw):  # levels = (a, z)
    loft(role, [octa(a, z, x, y) for a, z in levels], **kw)


# placa colada numa face inclinada do octógono. face 0 = frente; (a, z) embaixo e em cima
def plate(role, face, lo, hi, width, out):
    ang = math.radians(-90 + 45 * face)
    d, s = Vector((math.cos(ang), math.sin(ang), 0)), Vector((-math.sin(ang), math.cos(ang), 0))
    up = (d * hi[0] + Vector((0, 0, hi[1]))) - (d * lo[0] + Vector((0, 0, lo[1])))
    n = s.cross(up).normalized()
    if n.dot(d) < 0:
        n = -n
    rings = []
    for o in (-.1, out):
        rings.append([d * a + Vector((0, 0, z)) + s * w + n * o for a, z, w in (
            (*lo, -width / 2), (*lo, width / 2), (*hi, width / 2), (*hi, -width / 2))])
    loft(role, rings, bevel=.03)


k.begin()
# ---- base
box("TowerBlue", 0, 0, 0, 9.7, 9.7, 1.5, top=.985, bevel=.12, seg=2)
for sx in (1, -1):
    for sy in (1, -1):
        tri = [(4.35, 4.35), (2.15, 4.35), (2.15, 3.15), (3.15, 2.15), (4.35, 2.15)]
        loft("PlaneFlap", [[(sx * x, sy * y, z) for x, y in tri] for z in (1.4, 1.56)], bevel=.03)
stack("TowerBlue", [(3.45, 1.45), (3.45, 3.5), (3.3, 3.7)], bevel=.08)

# ---- entrada
box("TowerBlue", 0, -3.75, 1.4, 3.8, 2.2, 3.1, bevel=.12, seg=2)
box("TowerNavy", 0, -4.8, 1.46, 2.8, .26, 2.16, bevel=.04)
for s in (1, -1):
    box("TruckCab", s * .6, -4.9, 1.58, 1.06, .16, 1.92, bevel=.03)
    box("TowerNavy", s * .22, -5.0, 2.25, .15, .18, .5, bevel=.03)
box("Light", 0, -4.86, 3.86, 1.35, .16, .38, bevel=.05)
for i, (y0, h) in enumerate(((-6.3, .5), (-5.8, 1.0), (-5.3, 1.48))):
    box("PlaneFlap", 0, (y0 - 4.8) / 2, 0, 2.9, -4.8 - y0, h, bevel=.06)
for s in (1, -1):
    box("TowerBlue", s * 1.86, -5.5, 0, .78, 1.3, .95, bevel=.09)

# ---- corpo
stack("PlaneBody", [(2.8, 3.6), (2.8, 4.75)], bevel=.05)
stack("PlaneBody", [(2.8, 4.79), (2.8, 6.75)], bevel=.05)
stack("TowerNavy", [(2.74, 6.7), (2.74, 7.7)], bevel=0)
stack("PlaneBody", [(2.95, 7.65), (2.95, 8.75)], bevel=.05)
stack("PlaneBody", [(2.95, 8.79), (2.95, 9.9)], bevel=.05)
for f in (0, 2, 4, 6):
    plate("PlaneBody", f, (2.9, 3.6), (2.9, 9.8), 2.5, .2)
    for z in (4.75, 6.3, 7.85):
        plate("TowerNavy", f, (3.08, z), (3.08, z + .98), 1.86, .1)
        plate("TruckCab", f, (3.14, z + .14), (3.14, z + .84), 1.58, .1)

# ---- copa: saia azul-escura com luzes, anel
stack("TowerNavy", [(2.9, 9.55), (3.95, 9.85), (4.75, 11.2)], bevel=.07)
for f in range(8):
    plate("Light", f, (4.16, 10.2), (4.42, 10.64), 1.5, .07)
stack("TowerBlue", [(5.0, 11.05), (5.4, 11.3), (5.4, 12.45), (5.15, 12.7)], bevel=.07)

# ---- cabine de vidro, com montantes e mesas de controle dentro
Z0, A0, Z1, A1 = 12.75, 4.9, 16.05, 6.1
stack("TowerNavy", [(A0 + .12, 12.6), (A0 + .16, 12.95)], bevel=.04)
stack("TowerNavy", [(A1 - .02, 15.75), (A1 + .12, 16.1)], bevel=.04)
stack("TowerGlass", [(A0, Z0), (A1, Z1)], bevel=0)
lo, hi = octa(A0, Z0), octa(A1, Z1)
for a, b in zip(lo, hi):
    tube("TowerNavy", [a, b], [.24, .24], n=6, bevel=0)
for f in (1, 3, 5, 7):
    i = (f + 5) % 8
    j = (i + 1) % 8
    a, b = (Vector(lo[i]) + Vector(lo[j])) / 2, (Vector(hi[i]) + Vector(hi[j])) / 2
    tube("TowerNavy", [a, b], [.15, .15], n=6, bevel=0)
for f in range(0, 8, 2):
    ang = math.radians(-90 + 45 * f)
    d, s = Vector((math.cos(ang), math.sin(ang))), Vector((-math.sin(ang), math.cos(ang)))
    for role, dist, side, size, z, h in (
        ("TowerNavy", 3.2, 0, 1.3, 12.9, .95), ("PlaneBody", 3.2, 0, 1.0, 13.85, .5),
        ("TowerNavy", 3.1, 1.75, 1.2, 12.9, 1.5),
    ):
        c = d * dist + s * side
        box(role, c.x, c.y, z, size, size, h, bevel=.06)

# ---- teto
stack("TowerRoof", [(6.3, 16.05), (6.5, 16.25), (6.5, 17.25), (6.15, 17.6)], bevel=.08)
stack("TowerNavy", [(4.1, 17.5), (4.1, 17.85)], bevel=.05)
for f in range(1, 8, 2):
    ang = math.radians(-90 + 45 * f)
    box("TowerNavy", 3.95 * math.cos(ang), 3.95 * math.sin(ang), 17.5, 1.3, 1.3, 1.0, bevel=.08)
stack("PlaneBody", [(3.85, 17.8), (3.85, 18.85), (3.65, 19.05)], bevel=.07)
stack("TowerNavy", [(2.35, 18.95), (2.35, 19.75)], x=-.5, bevel=.08)
box("PlaneBody", 0, 0, 19.7, 1.8, 1.8, 1.0, top=.95, bevel=.14)
tube("TowerNavy", [(0, 0, 20.6), (0, 0, 23.2)], [.2, .2], n=8, bevel=0)
box("Light", 0, 0, 23.15, .62, .62, .68, bevel=.1)
box("TowerNavy", -1.95, -.3, 19.65, .55, .55, .7, bevel=.04)
box("PlaneBody", -1.95, -.3, 20.25, 1.55, 1.55, 1.35, bevel=.16, seg=2)

# ---- antena parabólica
box("TowerNavy", 2.65, -.3, 18.95, .85, .85, 1.5, bevel=.07)
axis = Vector((.5, -.5, .7)).normalized()
u = axis.cross(Vector((0, 0, 1))).normalized()
v = axis.cross(u)
C = Vector((2.75, -.3, 20.5))
tube("TowerNavy", [Vector((2.65, -.3, 20.2)), C + axis * .3], [.36, .36], n=8, bevel=0)
rings = []
for r, h in ((.5, .12), (1.25, .5), (1.72, .95), (1.76, 1.4), (1.58, 1.44), (1.1, 1.0), (.5, .72), (.06, .66)):
    rings.append([C + axis * h + (u * math.cos(2 * math.pi * i / 14) + v * math.sin(2 * math.pi * i / 14)) * r for i in range(14)])
loft("PlaneBody", rings, bevel=0)

meshes = k.finish("ControlTower")
if "export" in ARGS:
    k.export(meshes, os.path.join(HERE, "ControlTower.glb"))

k.stage((90, 226, 60), (1448, 1086))
which = [a for a in ARGS[1:] if a != "export"] or ["frente"]
VIEWS = {"frente": ((0, -56, 30), (0, 0, 11.2)), "lado": ((38, -40, 24), (0, 0, 11.5)), "tras": ((-30, 46, 26), (0, 0, 11.5))}
for w in which:
    k.shot(OUT + f"/torre_{w}.png", *VIEWS[w])
