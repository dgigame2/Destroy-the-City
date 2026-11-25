# Barracas: FruitStand (branca, com caixote de frutas) e FoodCart (madeira). Só prévia por enquanto.
# Rodar: blender --background --factory-startup --python assets/blender/build_stalls.py -- <pasta de saída> [export]
import math, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.dont_write_bytecode = True
sys.path.insert(0, HERE)
import kit as k
from kit import box, lerp, loft, prism_x, tube
from mathutils import Vector

ARGS = sys.argv[sys.argv.index("--") + 1:]
OUT = ARGS[0]
k.setup({
    "Awning": (0, 156, 250), "Stripe": (238, 238, 246), "PlaneBody": (214, 215, 228), "Metal": (112, 118, 140),
    "Beam": (164, 82, 36), "Plank": (216, 166, 80), "ToyRed": (214, 36, 40), "ToyYellow": (250, 200, 24),
    "TruckGreen": (44, 150, 44),
})


# toldo: fatias chanfradas, alto atrás (y1) e baixo na frente (y0)
def awning(x0, count, width, y0, y1, back, front, thick):
    for i in range(count):
        a = x0 + i * width
        poly = [(y0, front), (y1 - .5, back), (y1 - .12, back - .1), (y1, back - thick * .95), (y0 + .12, front - thick), (y0, front - thick + .06)]
        prism_x("Awning" if i % 2 == 0 else "Stripe", poly, a + .012, a + width - .012, bevel=.11, seg=2)


# altura do meio da espessura do toldo em y (para o poste entrar nele)
def roof_at(y, y0, y1, back, front, thick):
    return lerp(front, back, (y - y0) / (y1 - y0)) - thick * .6


def apple(x, y, z, r, spin):
    prof = [(-.92, .30), (-.80, .62), (-.35, .95), (.15, 1.0), (.58, .86), (.82, .56), (.80, .28), (.62, .06)]
    n = 12
    rings = []
    for h, w in prof:
        rings.append([(x + r * w * math.cos(2 * math.pi * i / n), y + r * w * math.sin(2 * math.pi * i / n), z + r * h) for i in range(n)])
    loft("ToyRed", rings, bevel=0, smooth=True)
    tube("Beam", [(x, y, z + r * .6), (x + .03, y, z + r * 1.0), (x + .07, y + .02, z + r * 1.4)], [.035, .03, .045], n=6, bevel=0)
    # folha: losango dobrado ao longo da nervura
    c, s = math.cos(spin), math.sin(spin)
    base = Vector((x + .03, y, z + r * 1.0))
    d, side, up = Vector((c, s, .35)), Vector((-s, c, 0)), Vector((0, 0, 1))
    L = r * 1.15
    pts = [base, base + d * L * .45 + side * L * .3, base + d * L, base + d * L * .45 - side * L * .3]
    low = [p - up * .03 for p in pts]
    mid = base + d * L * .5 + up * .05
    v = pts + low + [mid]
    f = [(0, 1, 8), (1, 2, 8), (2, 3, 8), (3, 0, 8), (4, 7, 6, 5), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]
    k.obj("TruckGreen", v, f, bevel=0)


# banana em arco: começa deitada na caixa e sobe para a direita
def banana(x, y, z, r, turn):
    pts = []
    for i in range(9):
        a = math.radians(lerp(-18, 84, i / 8))
        u = r * math.sin(a)
        pts.append((x + u * math.cos(turn), y + u * math.sin(turn), z + r * (1 - math.cos(a))))
    tube("ToyYellow", pts, [.05, .105, .14, .155, .16, .155, .14, .10, .06], n=8, bevel=0, smooth=True)
    p, q = Vector(pts[-1]), Vector(pts[-2])
    d = (p - q).normalized()
    tube("ToyYellow", [p - d * .03, p + d * .08], [.06, .055], n=6, bevel=0)
    tube("Beam", [p + d * .07, p + d * .12, p + d * .2], [.06, .07, .075], n=6, bevel=0)


def crate(cx, cy, z, w, d, h):
    t = .12
    for s in (1, -1):
        for j in range(2):  # duas ripas por lado
            zz = z + j * h / 2
            box("Beam", cx, cy + s * (d / 2 - t / 2), zz + .01, w - .1, t, h / 2 - .03, bevel=.025)
            box("Beam", cx + s * (w / 2 - t / 2), cy, zz + .01, t, d - .1, h / 2 - .03, bevel=.025)
        for q in (1, -1):
            box("Beam", cx + s * (w / 2 - .09), cy + q * (d / 2 - .09), z, .24, .24, h + .05, bevel=.04)
    box("Beam", cx, cy, z, w - .2, d - .2, h * .45, bevel=0)


# ---- barraca branca com frutas (lugar do IceCreamStand: 5 x 3,2 studs)
k.begin()
box("Metal", 0, 0, 0, 4.3, 2.35, .3, bevel=.1)
box("PlaneBody", 0, 0, .28, 4.5, 2.5, 1.95, bevel=.16, seg=2)
box("PlaneBody", 0, 0, 2.12, 4.95, 3.0, .72, bevel=.17, seg=2)
Y0, Y1, BACK, FRONT, TH = -1.35, 1.2, 6.8, 5.75, .85
awning(-2.5, 5, 1.0, Y0, Y1, BACK, FRONT, TH)
for x in (-1.95, 1.95):
    box("Metal", x, .1, 2.8, .58, .58, roof_at(.1, Y0, Y1, BACK, FRONT, TH) - 2.8, bevel=.04)
CX, CY, CZ = 0, -.45, 2.84
crate(CX, CY, CZ, 2.1, 1.35, .62)
for ax, ay, az, sp in ((-.74, -.28, .62, 2.6), (-.26, -.34, .64, .4), (-.7, .18, .68, 1.9), (-.24, .14, .72, 2.4), (.1, .36, .66, .6)):
    apple(CX + ax, CY + ay, CZ + az, .27, sp)
for bx, by, r, turn in ((-.02, -.34, .78, .05), (.06, -.12, .84, .1), (.12, .12, .84, .2), (.18, .34, .78, .25)):
    banana(CX + bx, CY + by, CZ + .42, r, turn)
fruit = k.finish("FruitStand")

# ---- barraca de madeira (lugar do FoodCart: 6,4 x 4,4 studs)
k.begin()
box("Beam", 0, .25, 0, 5.5, 2.5, .26, bevel=.05)
box("Plank", 0, .25, .22, 5.3, 2.3, 2.3, bevel=.05)
for x in (-2.62, 2.62):  # moldura dos lados
    box("Beam", x, 1.3, .1, .22, .5, 2.4, bevel=.04)
box("Beam", 0, .25, 2.45, 5.95, 2.95, .58, bevel=.13, seg=2)
Y0, Y1, BACK, FRONT, TH = -1.75, 1.95, 7.0, 5.65, .85
awning(-3.2, 6, 6.4 / 6, Y0, Y1, BACK, FRONT, TH)
for x in (-2.75, 2.75):
    for y in (-1.15, 1.6):
        box("Beam", x, y, 0, .64, .64, roof_at(y, Y0, Y1, BACK, FRONT, TH), bevel=.05)
cart = k.finish("FoodCart")

if "export" in ARGS:
    k.export(fruit, os.path.join(HERE, "FruitStand.glb"))
    k.export(cart, os.path.join(HERE, "FoodCart.glb"))

# ---- prévia
for o in fruit:
    o.location.x = -4.1
for o in cart:
    o.location.x = 4.1
k.stage((118, 226, 84))
which = [a for a in ARGS[1:] if a != "export"] or ["frente", "perto", "tras"]
if "frente" in which:
    k.shot(OUT + "/barracas_frente.png", (-11, -25, 15), (.1, 0, 3.2))
if "perto" in which:
    k.shot(OUT + "/barracas_frutas.png", (-8.2, -10, 6.6), (-4.1, -.3, 3.8))
if "tras" in which:
    k.shot(OUT + "/barracas_tras.png", (12, 21, 14), (0, 0, 3.0))
