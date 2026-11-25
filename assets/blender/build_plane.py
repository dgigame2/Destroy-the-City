# Avião (Plane): gera Plane.glb ao lado deste arquivo (uma mesh por papel de cor), mostra o Size/Center do
# MeshModelsConfig e renderiza prévias.
# Rodar: blender --background --factory-startup --python assets/blender/build_plane.py -- <pasta de saída> [vistas]
# Unidades em studs, base em z=0, frente para -Y.
import bpy, bmesh, math, os, sys
from mathutils import Matrix, Vector

ARGS = sys.argv[sys.argv.index("--") + 1:]
OUT = ARGS[0]
COLORS = {
    "WallWhite": (240, 237, 240), "Concrete": (218, 220, 230), "Accent": (228, 48, 56),
    "PlaneBand": (134, 198, 244), "PlaneWindow": (52, 158, 232), "Steel": (148, 152, 178),
    "ToyDark": (84, 90, 104), "Tire": (40, 40, 46),
}
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
parts = {r: [] for r in COLORS}


def lin(c):
    c /= 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


mats = {}
for role, rgb in COLORS.items():
    mt = bpy.data.materials.new(role)
    mt.use_nodes = True
    bs = mt.node_tree.nodes["Principled BSDF"]
    bs.inputs["Base Color"].default_value = (*[lin(c) for c in rgb], 1)
    bs.inputs["Roughness"].default_value = 0.55
    mats[role] = mt


def obj(role, verts, faces, bevel=0.07, seg=1, flat=False):
    me = bpy.data.meshes.new(role)
    me.from_pydata([tuple(v) for v in verts], [], faces)
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(role, me)
    scene.collection.objects.link(o)
    me.materials.append(mats[role])
    for p in me.polygons:
        p.use_smooth = bool(bevel) and not flat
    if bevel:
        md = o.modifiers.new("b", "BEVEL")
        md.width = bevel
        md.segments = seg
        md.limit_method = "ANGLE"
        md.angle_limit = math.radians(9)
        md.harden_normals = not flat
    parts[role].append(o)
    return o


def loft(role, rings, **kw):
    n = len(rings[0])
    v = [p for r in rings for p in r]
    f = []
    for i in range(len(rings) - 1):
        for k in range(n):
            a, b = i * n + k, i * n + (k + 1) % n
            f.append((a, b, b + n, a + n))
    f.append(tuple(range(n)))
    f.append(tuple(range(len(v) - n, len(v))))
    return obj(role, v, f, **kw)


# polígono (y,z) puxado em x
def prism_x(role, poly, x0, x1, shrink=1.0, **kw):
    cy = sum(p[0] for p in poly) / len(poly)
    cz = sum(p[1] for p in poly) / len(poly)
    far = [(x1, cy + (y - cy) * shrink, cz + (z - cz) * shrink) for y, z in poly]
    return loft(role, [[(x0, y, z) for y, z in poly], far], **kw)


# z = base; top = escala do topo
def box(role, x, y, z, sx, sy, sz, top=1.0, **kw):
    def r(k, zz):
        a, b = sx / 2 * k, sy / 2 * k
        return [(x - a, y - b, zz), (x + a, y - b, zz), (x + a, y + b, zz), (x - a, y + b, zz)]
    return loft(role, [r(1, z), r(top, z + sz)], **kw)


# ---- fuselagem: anel de 12 pontos com lateral reta, chanfros e teto/barriga planos
FR = [(.44, 0), (.80, .10), (1, .28), (1, .74), (.80, .92), (.42, 1)]


def ring(y, w, zb, zt):
    h = zt - zb
    r = [(fx * w, y, zb + fz * h) for fx, fz in FR]
    return r + [(-x, yy, z) for x, yy, z in reversed(r)]


MAIN = [(-9.46, 2.1, 2.2, 6.2), (6.4, 2.1, 2.2, 6.2)]
COLLAR = [(6.44, 2.2, 2.15, 6.3), (7.5, 2.2, 2.2, 6.3), (8.7, 2.06, 2.62, 6.22)]
TAIL = [(8.74, 1.96, 2.75, 6.1), (11.2, 1.6, 3.6, 6.1), (13.4, 1.2, 4.4, 6.05), (14.5, 1.02, 4.7, 5.95)]
for s in (MAIN, COLLAR, TAIL):
    loft("WallWhite", [ring(*a) for a in s], bevel=0.09, seg=2)


# ---- nariz facetado: níveis de altura, cada um com 4 colunas de um lado (emenda, lateral, bochecha, frente)
NOSE = [
    [(.95, -9.5, 2.15), (.95, -11.2, 2.15), (.85, -12.8, 2.15), (.5, -13.2, 2.15)],
    [(1.73, -9.5, 2.56), (1.73, -11.45, 2.5), (1.38, -13.45, 2.5), (.75, -14.0, 2.5)],
    [(2.16, -9.5, 3.3), (2.16, -11.7, 3.25), (1.72, -13.9, 3.2), (.9, -14.7, 3.2)],
    [(2.16, -9.5, 4.3), (2.16, -11.6, 4.3), (1.69, -13.7, 4.25), (.88, -14.45, 4.25)],
    [(2.16, -9.5, 5.2), (2.14, -11.25, 4.85), (1.6, -12.85, 4.85), (.82, -13.25, 4.85)],
    [(1.73, -9.5, 5.94), (1.74, -10.55, 5.98), (1.34, -11.6, 6.0), (.7, -11.8, 6.0)],
    [(.91, -9.5, 6.27), (.91, -10.2, 6.27), (.78, -10.85, 6.27), (.45, -10.95, 6.27)],
]


def nose_ring(lv):
    return lv + [(-x, y, z) for x, y, z in reversed(lv)]


verts = [q for lv in NOSE for q in nose_ring(lv)]
faces = []
for i in range(len(NOSE) - 1):
    for k in range(7):
        a = i * 8 + k
        faces.append((a, a + 1, a + 9, a + 8))
faces.append(tuple(range(8)))
faces.append(tuple(range(len(verts) - 8, len(verts))))
faces.append(tuple(i * 8 for i in range(len(NOSE))) + tuple(i * 8 + 7 for i in reversed(range(len(NOSE)))))
obj("WallWhite", verts, faces, bevel=.06, flat=True)


# vidro: colunas (baixo, cima) sobre o nariz, com moldura embaixo
def glass(cols, thick=.06):
    n = len(cols)
    flat_pts = [q for c in cols for q in c]
    normals = []
    for i in range(n):
        du = cols[min(i + 1, n - 1)][0] - cols[max(i - 1, 0)][0]
        nn = du.cross(cols[i][1] - cols[i][0]).normalized()
        if nn.dot(cols[i][0] - Vector((0, -9.5, 4))) < 0:
            nn = -nn
        normals += [nn, nn]
    v = [q - k * .05 for q, k in zip(flat_pts, normals)] + [q + k * thick for q, k in zip(flat_pts, normals)]
    T = 2 * n
    f = []
    for i in range(n - 1):
        a = 2 * i
        f.append((a, a + 1, a + 3, a + 2))
        f.append((T + a, T + a + 1, T + a + 3, T + a + 2))
        f.append((a, a + 2, T + a + 2, T + a))
        f.append((a + 1, a + 3, T + a + 3, T + a + 1))
    f.append((0, 1, T + 1, T))
    f.append((T - 2, T - 1, 2 * T - 1, 2 * T - 2))
    obj("PlaneWindow", v, f, bevel=.025, flat=True)


def nv(level, col, m=1):
    x, y, z = NOSE[level][col]
    return Vector((m * x, y, z))


def column(q0, q1, t, v0, v1):  # t entre duas colunas; v0/v1 = recuo embaixo e em cima
    lo, hi = q0[0].lerp(q1[0], t), q0[1].lerp(q1[1], t)
    return lo.lerp(hi, v0), lo.lerp(hi, v1)


for m in (1, -1):
    A, B = (nv(4, 1, m), nv(5, 1, m)), (nv(4, 2, m), nv(5, 2, m))
    glass([column(A, B, .02, .07, .86), column(A, B, .86, .07, .86)])
BR, CR = (nv(4, 2), nv(5, 2)), (nv(4, 3), nv(5, 3))
BL, CL = (nv(4, 2, -1), nv(5, 2, -1)), (nv(4, 3, -1), nv(5, 3, -1))
glass([column(BR, CR, .12, .07, .9), column(CR, CR, 0, .07, .9), column(CL, CL, 0, .07, .9), column(BL, CL, .12, .07, .9)])

# placas do teto
for y0, y1 in ((-9.1, -3.05), (-2.95, 6.0)):
    sec = [(-1.45, 5.85), (1.45, 5.85), (1.45, 6.12), (.95, 6.38), (-.95, 6.38), (-1.45, 6.12)]
    loft("WallWhite", [[(x, y, z) for x, z in sec] for y in (y0, y1)], bevel=.06)
box("WallWhite", 0, -5.4, 6.36, 1.0, 1.5, .34, top=.86)
box("WallWhite", 0, 1.4, 6.36, .62, .62, .42, top=.86)
box("WallWhite", 0, 2.7, 6.36, .62, .62, .42, top=.86)
# barriga (carenagem da raiz da asa)
belly = []
for y, w, d in ((-5.4, 1.0, .35), (-4.4, 1.5, 0), (3.6, 1.5, 0), (5.0, 1.0, .35)):
    belly.append([(-w, y, 2.0 + d), (w, y, 2.0 + d), (w + .75, y, 2.75), (w + .75, y, 3.3), (-w - .75, y, 3.3), (-w - .75, y, 2.75)])
loft("WallWhite", belly, bevel=.08)


def rrect(cy, cz, w, h, r, n=2):
    pts = []
    for sx, sz, a0 in ((1, 1, 0), (-1, 1, 90), (-1, -1, 180), (1, -1, 270)):
        for i in range(n + 1):
            a = math.radians(a0 + 90 * i / n)
            pts.append((cy + sx * (w / 2 - r) + r * math.cos(a), cz + sz * (h / 2 - r) + r * math.sin(a)))
    return pts


for m in (1, -1):
    prism_x("PlaneBand", rrect(-1.6, 4.42, 13.7, 1.14, .16), m * 2.05, m * 2.17, shrink=.997, bevel=0)
    for k in range(13):
        prism_x("PlaneWindow", rrect(-7.72 + k * 1.02, 4.42, .64, .70, .16), m * 2.12, m * 2.24, shrink=.9, bevel=0)


# ---- asas
def lerp(a, b, t):
    return a + (b - a) * t


# le/te/z0/z1 são funções de x; chamfer = borda de ataque chanfrada
def slab(role, m, x0, x1, le, te, z0, z1, bevel=.06, chamfer=0):
    rings = []
    for x in (x0, x1):
        a, b, lo, hi = le(x), te(x), z0(x), z1(x)
        c = chamfer
        if c:
            sec = [(a + c, lo), (a, lerp(lo, hi, .45)), (a + c * .6, hi), (b - c * .3, hi), (b, lerp(lo, hi, .5)), (b - c * .3, lo)]
        else:
            sec = [(a, lo), (a, hi), (b, hi), (b, lo)]
        rings.append([(m * x, y, z) for y, z in sec])
    loft(role, rings, bevel=bevel)


def span(a, b):
    return lambda x: lerp(a, b, (x - 1.7) / 12.0)


def off(f, d):
    return lambda x: f(x) + d


LE, TE, ZB, ZT = span(-4.3, 1.1), span(2.6, 4.0), span(2.75, 3.25), span(3.5, 3.78)
EX, EZ = 6.2, 1.62
for m in (1, -1):
    for a, b in ((1.7, 5.6), (5.64, 9.7), (9.74, 13.7)):
        slab("WallWhite", m, a, b, LE, TE, ZB, ZT, chamfer=.35)
    low = off(ZT, -.05)
    # placa comprida de cima
    slab("WallWhite", m, 2.6, 10.9, off(LE, .75), lambda x: lerp(0.9, 2.55, (x - 2.6) / 8.3), low, off(ZT, .16), bevel=.05)
    # flaps e detalhes da ponta
    slab("Concrete", m, 4.3, 7.9, off(TE, -1.75), off(TE, -.12), low, off(ZT, .26), bevel=.06)
    slab("WallWhite", m, 8.1, 10.4, off(TE, -1.25), off(TE, -.12), low, off(ZT, .2), bevel=.05)
    slab("WallWhite", m, 11.1, 13.3, off(LE, .55), off(LE, 1.35), low, off(ZT, .14), bevel=.04)
    slab("Concrete", m, 10.7, 12.1, off(TE, -1.05), off(TE, -.15), low, off(ZT, .16), bevel=.04)
    slab("WallWhite", m, 12.25, 13.4, off(TE, -1.05), off(TE, -.15), low, off(ZT, .16), bevel=.04)
    # ponta da asa
    prism_x("Accent", [(.95, 3.0), (4.25, 3.0), (4.25, 5.15), (2.75, 5.15), (.95, 3.95)], m * 13.68, m * 14.3, shrink=.95, bevel=.1)

    # ---- turbina: anel quadrado arredondado (superelipse)
    def er(y, r, n=16):
        pts = []
        for i in range(n):
            t = 2 * math.pi * (i + .5) / n
            c, s = math.cos(t), math.sin(t)
            p = 2 / 2.7
            pts.append((m * EX + r * math.copysign(abs(c) ** p, c), y, EZ + r * math.copysign(abs(s) ** p, s)))
        return pts

    def lathe(role, prof, bevel):
        loft(role, [er(y, r) for y, r in prof], bevel=bevel)

    # boca aberta: por fora, pelo lábio e para dentro
    lathe("WallWhite", [(-4.7, 1.28), (-5.35, 1.28), (-5.75, 1.14), (-5.75, .95), (-5.5, .86), (-5.0, .86)], 0)
    lathe("ToyDark", [(-5.04, .85), (-4.8, .85)], 0)
    lathe("Accent", [(-4.66, 1.3), (-3.2, 1.26)], 0)
    lathe("Concrete", [(-3.16, 1.16), (-2.0, 1.02), (-1.2, .72)], .05)
    lathe("Steel", [(-1.2, .5), (-.8, .34)], 0)
    lathe("Steel", [(-5.0, .34), (-5.32, .3), (-5.5, .16)], 0)
    for i in range(6):
        a = math.radians(60 * i + 15)
        d = Vector((math.cos(a), 0, math.sin(a)))
        t = Vector((-math.sin(a), 0, math.cos(a)))
        c = Vector((m * EX, -5.16, EZ))
        quad = [c + d * .26 - t * .1, c + d * .26 + t * .1, c + d * .84 + t * .17, c + d * .84 - t * .17]
        rings = []
        for q in (-.03, .05):
            rings.append([p + Vector((0, (.07 if j in (0, 3) else -.07) + q, 0)) for j, p in enumerate(quad)])
        loft("Steel", rings, bevel=0)
    # suporte da turbina
    rings = []
    for z, w, y0, y1 in ((2.55, .5, -4.75, -1.4), (3.05, .5, -4.5, -1.4), (3.4, .42, -3.4, -1.4)):
        rings.append([(m * EX - w, y0, z), (m * EX + w, y0, z), (m * EX + w, y1, z), (m * EX - w, y1, z)])
    loft("WallWhite", rings, bevel=.06)

    # ---- estabilizador
    def TL(x):
        return lerp(10.5, 12.3, (x - 1.0) / 5.2)

    def TT(x):
        return lerp(13.7, 14.6, (x - 1.0) / 5.2)

    def kz(v):
        return lambda x: v + (x - 1) * .05

    slab("WallWhite", m, 1.0, 4.0, TL, TT, kz(4.65), kz(5.35), chamfer=.3)
    slab("WallWhite", m, 4.04, 6.2, TL, TT, kz(4.65), kz(5.35), chamfer=.3)
    slab("WallWhite", m, 1.9, 5.8, off(TL, .8), off(TT, -.3), kz(5.3), kz(5.5), bevel=.05)


# ---- leme
def fin(poly, w0, w1, bevel=.08):
    z0, z1 = min(p[1] for p in poly), max(p[1] for p in poly)
    rings = []
    for s in (-1, 1):
        rings.append([(s * lerp(w0, w1, (z - z0) / (z1 - z0)) / 2, y, z) for y, z in poly])
    loft("Accent", rings, bevel=bevel)


rings = []
for z, w, y0, y1 in ((5.8, .95, 7.6, 14.2), (6.45, .95, 7.6, 14.2), (6.8, .72, 8.2, 14.1)):
    rings.append([(-w, y0, z), (w, y0, z), (w, y1, z), (-w, y1, z)])
loft("Accent", rings, bevel=.09)
fin([(8.9, 6.75), (12.55, 6.75), (13.2, 10.9), (11.9, 10.9)], .86, .62)
fin([(12.62, 6.75), (13.9, 6.75), (14.35, 10.9), (13.27, 10.9)], .7, .5)
fin([(11.75, 10.95), (14.45, 10.95), (14.55, 11.75), (12.1, 11.95)], .84, .72, .1)


# ---- trem de pouso
def disc(role, x0, x1, y, z, r, n=10, bevel=.05):
    rings = []
    for x in (x0, x1):
        rings.append([(x, y + r * math.cos(2 * math.pi * (i + .5) / n), z + r * math.sin(2 * math.pi * (i + .5) / n)) for i in range(n)])
    loft(role, rings, bevel=bevel)


def gear(x, y, top, r, dx):
    box("WallWhite", x, y, top - .35, 1.1, 1.3, .5, bevel=.06)
    box("Steel", x, y, top - 1.0, .6, .62, .7, bevel=.06)
    box("Steel", x, y, r - .18, .36, .36, top - r - .7, bevel=.04)
    box("Steel", x, y, r - .18, dx * 2, .34, .34, bevel=.04)
    for s in (1, -1):
        disc("Tire", x + s * (dx - .05), x + s * (dx + .42), y, r, r, bevel=.08)
        disc("Steel", x + s * (dx + .38), x + s * (dx + .48), y, r, r * .46, bevel=0)


gear(0, -11.2, 2.45, .58, .32)
for m in (1, -1):
    gear(m * 2.7, .9, 2.95, .62, .34)

# ---- junta por papel
tris = {}
meshes = []
for role, group in parts.items():
    bpy.ops.object.select_all(action="DESELECT")
    for o in group:
        o.select_set(True)
        bpy.context.view_layer.objects.active = o
    bpy.ops.object.convert(target="MESH")
    bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active
    o.name = f"M_Plane_{role}"
    o.data.calc_loop_triangles()
    tris[role] = len(o.data.loop_triangles)
    meshes.append(o)
co = [v.co for o in meshes for v in o.data.vertices]
lo = [round(min(c[i] for c in co), 2) for i in range(3)]
hi = [round(max(c[i] for c in co), 2) for i in range(3)]
print("TRIS", tris, sum(tris.values()), "BOUNDS", lo, hi)
bpy.ops.wm.save_as_mainfile(filepath=OUT + "/plane.blend")

# ---- exporta: gira 180 graus (frente -Z no Roblox: (x, y, z) -> (x, z, -y))
turn = Matrix.Rotation(math.pi, 4, "Z")
bpy.ops.object.select_all(action="DESELECT")
for o in meshes:
    o.data.name = o.name
    o.data.transform(turn)
    o.select_set(True)
    c0 = [min(v.co[i] for v in o.data.vertices) for i in range(3)]
    c1 = [max(v.co[i] for v in o.data.vertices) for i in range(3)]
    size = [c1[i] - c0[i] for i in range(3)]
    mid = [(c1[i] + c0[i]) / 2 for i in range(3)]
    print("PIECE", o.name, "{ %.3f, %.3f, %.3f }" % (size[0], size[2], size[1]), "{ %.3f, %.3f, %.3f }" % (mid[0], mid[2], -mid[1]))
bpy.ops.export_scene.gltf(filepath=os.path.join(os.path.dirname(os.path.abspath(__file__)), "Plane.glb"), use_selection=True)
for o in meshes:
    o.data.transform(turn)

# ---- prévia
bpy.ops.mesh.primitive_plane_add(size=400)
ground = bpy.context.object
gm = bpy.data.materials.new("g")
gm.use_nodes = True
gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (lin(138), lin(146), lin(196), 1)
gm.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 1
ground.data.materials.append(gm)
sun = bpy.data.objects.new("s", bpy.data.lights.new("s", "SUN"))
scene.collection.objects.link(sun)
sun.data.energy = 2.1
sun.data.angle = .12
sun.rotation_euler = (math.radians(40), math.radians(-18), math.radians(-25))
w = bpy.data.worlds.new("w")
scene.world = w
w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (.80, .84, 1, 1)
w.node_tree.nodes["Background"].inputs[1].default_value = .5
cam = bpy.data.objects.new("c", bpy.data.cameras.new("c"))
scene.collection.objects.link(cam)
scene.camera = cam
cam.data.lens = 60
scene.render.engine = "CYCLES"
scene.cycles.samples = 48
scene.cycles.use_denoising = True
scene.render.resolution_x, scene.render.resolution_y = 1448, 1086
scene.view_settings.view_transform = "Standard"


def shot(name, pos, look=(0, -.3, 4)):
    cam.location = pos
    cam.rotation_euler = (Vector(look) - Vector(pos)).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = OUT + "/" + name + ".png"
    bpy.ops.render.render(write_still=True)


which = ARGS[1:] or ["frente", "perto", "tras", "azul"]
if "frente" in which:
    shot("aviao_frente", (-35, -37, 31))
if "perto" in which:
    shot("aviao_perto", (-15, -27, 12), (-1, -9, 4))
if "tras" in which:
    shot("aviao_tras", (34, 38, 27))
if "azul" in which:
    mats["Accent"].node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (lin(40), lin(110), lin(236), 1)
    shot("aviao_azul", (33, -38, 24))
