# Breeze low poly: 6 segmentos, cada um gira no PROPRIO eixo; a curva do corpo (espinha) fica parada.
# Tudo que gira tem simetria tripla, entao o centro de massa cai no eixo e nada balanca.
# Roda dentro do Blender; cria a cena "Breeze_LowPoly" e nao mexe nas outras.
import bpy, math
from mathutils import Vector

SCENE = "Breeze_LowPoly"
H, FOLD, SEGS = 4.7, 3, 6
LOOP = 96            # quadros do ciclo (24 fps)
TURNS = [4, 3, 3, 2, 2, 2]  # voltas por ciclo, do pe ao topo (pe mais rapido)
COL = {"main": "F5FBFF", "core": "CFE9F8", "low": "A9D6EF", "pale": "FFFFFF", "deep": "7FBFE3"}

# perfil: altura (0..1) -> raio; crescente e suave, com o topo aberto
PROFILE = [(0, .05), (.08, .12), (.2, .23), (.35, .39), (.5, .58), (.65, .82), (.8, 1.08), (.92, 1.3), (1, 1.36)]
def radius(t):
    t = min(max(t, 0), 1)
    for (a, ra), (b, rb) in zip(PROFILE, PROFILE[1:]):
        if t <= b:
            return ra + (rb - ra) * (t - a) / (b - a)
def spine(t):
    k = min(max(t, 0) / .5, 1); return _spine(t) * (k * k * (3 - 2 * k))  # o pe fica reto
def _spine(t):  # desvio lateral pequeno, volta a 0 no pe e no topo: a curva nao gira
    return Vector((.21 * math.sin(math.pi * 2 * t) * (1 - .3 * t), .06 * math.sin(math.pi * t), 0))

old = bpy.data.scenes.get(SCENE)
if old:
    for o in list(old.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    sc = old
else:
    sc = bpy.data.scenes.new(SCENE)

def lin(h):
    f = lambda c: c / 12.92 if c <= .04045 else ((c + .055) / 1.055) ** 2.4
    return tuple(f(int(h[i:i + 2], 16) / 255) for i in (0, 2, 4)) + (1,)
def material(name):
    m = bpy.data.materials.get("Breeze_" + name) or bpy.data.materials.new("Breeze_" + name)
    m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = lin(COL[name]); b.inputs["Roughness"].default_value = .75
    m.diffuse_color = lin(COL[name])
    return m
MATS = {k: material(k) for k in COL}

class Geo:
    def __init__(self): self.v, self.f, self.m = [], [], []
    def rot3(self, verts, faces, mat):  # copia com simetria
        for k in range(FOLD):
            a = 2 * math.pi * k / FOLD; ca, sa = math.cos(a), math.sin(a); n = len(self.v)
            self.v += [(x * ca - y * sa, x * sa + y * ca, z) for x, y, z in verts]
            self.f += [tuple(i + n for i in f) for f in faces]; self.m += [mat] * len(faces)
    def crescent(self, z, r, span, thick, tall, rise, grow, start, mat, steps=12, sides=6, power=.55):
        # cordao curvo que afina nas duas pontas
        rings, verts, faces = [], [], []
        for i in range(steps + 1):
            u = i / steps; a = start + span * u
            taper = math.sin(math.pi * u) ** power if 0 < u < 1 else 0
            rr = r + grow * (u - .5); zz = z + rise * (u - .5)
            if taper == 0:
                rings.append([len(verts)]); verts.append((rr * math.cos(a), rr * math.sin(a), zz)); continue
            ring = []
            for s in range(sides):
                b = 2 * math.pi * s / sides
                q = rr + thick * taper * math.cos(b)
                ring.append(len(verts)); verts.append((q * math.cos(a), q * math.sin(a), zz + tall * taper * math.sin(b)))
            rings.append(ring)
        for A, B in zip(rings, rings[1:]):
            for s in range(sides):
                n = (s + 1) % sides
                if len(A) == 1: faces.append((A[0], B[s], B[n]))
                elif len(B) == 1: faces.append((A[s], B[0], A[n]))
                else: faces.append((A[s], B[s], B[n], A[n]))
        self.rot3(verts, faces, mat)
    def pebble(self, z, r, size, ang, mat):
        # pedrinha: octaedro truncado simples
        verts, faces = [], []
        cx, cy = r * math.cos(ang), r * math.sin(ang)
        for lz, lr in ((-.85, 0), (-.5, .8), (.35, .9), (.9, 0)):
            if lr == 0: verts.append((cx, cy, z + lz * size)); continue
            for s in range(6):
                b = math.pi / 3 * s + (lz > 0) * math.pi / 6
                verts.append((cx + lr * size * math.cos(b), cy + lr * size * math.sin(b), z + lz * size))
        for s in range(6):
            n = (s + 1) % 6
            faces += [(0, 1 + n, 1 + s), (1 + s, 1 + n, 7 + s), (1 + n, 7 + n, 7 + s), (7 + s, 7 + n, 13)]
        self.rot3(verts, faces, mat)
    def build(self, name, loc):
        me = bpy.data.meshes.new(name); me.from_pydata(self.v, [], self.f)
        order = list(COL)
        for k in order: me.materials.append(MATS[k])
        for p, k in zip(me.polygons, self.m): p.material_index = order.index(k); p.use_smooth = False
        import bmesh
        bm = bmesh.new(); bm.from_mesh(me); bmesh.ops.recalc_face_normals(bm, faces=bm.faces); bm.to_mesh(me); bm.free()
        o = bpy.data.objects.new(name, me); o.location = loc; sc.collection.objects.link(o)
        return o

root = bpy.data.objects.new("Breeze", None); sc.collection.objects.link(root)
spin = []
# nucleo parado: um tubo que segue a espinha e fecha as emendas (sobe por fora e desce por dentro no topo)
g = Geo(); N = 10; rows = 8; prev = None
path = [(i / rows, radius(i / rows) * .80) for i in range(rows + 1)] + [(1.0, .95), (.9, .72), (.8, .4), (.74, .0)]
for t, r in path:
    c = spine(t); n = len(g.v)
    g.v += [(c.x + r * math.cos(2 * math.pi * k / N), c.y + r * math.sin(2 * math.pi * k / N), t * H) for k in range(N)]
    if prev is not None:
        for k in range(N):
            q = (k + 1) % N
            g.f.append((prev + k, prev + q, n + q, n + k)); g.m.append("core" if t > .45 or r < .3 else "low")
    prev = n
core = g.build("Breeze_Core", (0, 0, 0)); core.parent = root

# faixas: 2 a 3 por segmento, cruzadas em diagonal
edges = [0, .13, .27, .42, .58, .77, 1.0]
for s in range(SEGS):
    t0, t1 = edges[s], edges[s + 1]; tm = (t0 + t1) / 2; c = spine(tm)
    g = Geo(); bands = 2 if s == 0 else 3
    for b in range(bands):
        t = t0 + (t1 - t0) * (b + .5) / bands; r = radius(t)
        gap = (t1 - t0) * H / bands
        mat = ("deep", "low", "main")[(b + s) % 3] if s < 3 else ("main", "low", "core", "main")[(b * 2 + s) % 4]
        fat = (1.0, .72, .86)[b]
        # grosso + fino, um subindo bem mais que o outro: os cordoes se cruzam
        g.crescent((t - tm) * H, r * (.93 + .03 * b), math.radians(250 if s == 0 else (225, 165, 195)[b]), max(.035, r * .18) * fat, gap * .50 * fat,
                   gap * ((.5, .6, .5)[b] if s == 0 else (1.0, 2.0, 1.4)[b]), r * (.08, .14, .1)[b], 1.7 * s + 2.4 * b, mat, steps=(8, 7, 7)[b], sides=4, power=.6)
    if s == 5:  # borda do topo: tres cordoes grossos
        g.crescent((.985 - tm) * H, 1.36, math.radians(230), .23, .19, .34, .2, .4, "main", steps=10, sides=4)
        g.crescent((1.02 - tm) * H, 1.04, math.radians(190), .14, .10, .12, -.25, 1.5, "low", steps=7, sides=4)
    o = g.build("Breeze_Seg%d" % (s + 1), (c.x, c.y, tm * H)); o.parent = root; spin.append((o, TURNS[s]))

# detalhes soltos: crescentes finos e pedrinhas em trios (giram no eixo do trecho onde estao)
for i, (t, off, span, size, turns) in enumerate(((1.0, .36, 130, .05, 1), (.62, .42, 105, .045, 2), (.3, .30, 125, .035, 2))):
    c = spine(t); g = Geo(); r = radius(t) + off
    g.crescent(0, r, math.radians(span), .13 if i == 0 else .10 - .02 * i, size, .30 - .05 * i, .16, 1.3 * i, "pale", steps=7, sides=3, power=.8)
    if i < 2:
        g.pebble(-.28, r - .05, .115 - .025 * i, 2.6 + i, "pale")
        g.pebble(.2 - .5 * i, r + .05, .07, 1.0 + 2 * i, "low")
    o = g.build("Breeze_Wind%d" % (i + 1), (c.x, c.y, t * H)); o.parent = root; spin.append((o, turns))

# giro em ciclo perfeito
sc.frame_start, sc.frame_end, sc.render.fps = 1, LOOP, 24
for o, turns in spin:
    o.rotation_euler = (0, 0, 0); o.keyframe_insert("rotation_euler", index=2, frame=1)
    o.rotation_euler[2] = 2 * math.pi * turns; o.keyframe_insert("rotation_euler", index=2, frame=LOOP + 1)
    act = o.animation_data.action
    curves = act.fcurves if hasattr(act, "fcurves") else [f for l in act.layers for st in l.strips for bag in st.channelbags for f in bag.fcurves]
    for fc in curves:
        for k in fc.keyframe_points: k.interpolation = "LINEAR"

# medida do balanceamento: centro do volume/area de cada peca em relacao ao eixo dela, e raio por lado
report = []
for o, turns in spin:
    cx = cy = area = 0
    for p in o.data.polygons: cx += p.center.x * p.area; cy += p.center.y * p.area; area += p.area
    far = [0] * 72
    for v in o.data.vertices:
        far[int(((math.atan2(v.co.y, v.co.x) + 2 * math.pi) % (2 * math.pi)) / (2 * math.pi) * 72) % 72] = max(far[int(((math.atan2(v.co.y, v.co.x) + 2 * math.pi) % (2 * math.pi)) / (2 * math.pi) * 72) % 72], math.hypot(v.co.x, v.co.y))
    R = max(far)
    report.append((o.name, round(math.hypot(cx, cy) / area / R * 100, 4)))
    assert math.hypot(cx, cy) / area / R < .001, o.name
for o in list(sc.objects):
    o["tris"] = sum(len(p.vertices) - 2 for p in o.data.polygons) if o.type == "MESH" else 0

# camera e luz so para avaliar
cam = bpy.data.objects.new("Breeze_Cam", bpy.data.cameras.new("Breeze_Cam")); sc.collection.objects.link(cam)
cam.location = (0, -12.5, 4.6); cam.rotation_euler = (Vector((0, 0, 2.4)) - cam.location).to_track_quat("-Z", "Y").to_euler()
cam.data.lens = 70; sc.camera = cam
for n, loc, e, size in (("Key", (-4, -5, 6), 520, 2.5), ("Fill", (5, -4, 3), 130, 5), ("Rim", (1, 6, 5), 250, 3)):
    l = bpy.data.lights.new("Breeze_" + n, "AREA"); l.energy = e; l.size = size
    lo = bpy.data.objects.new("Breeze_" + n, l); lo.location = loc
    lo.rotation_euler = (Vector((0, 0, 2)) - lo.location).to_track_quat("-Z", "Y").to_euler(); sc.collection.objects.link(lo)
w = bpy.data.worlds.get("Breeze_World") or bpy.data.worlds.new("Breeze_World"); w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (.10, .22, .33, 1); w.node_tree.nodes["Background"].inputs[1].default_value = .75
sc.world = w; sc.view_settings.view_transform = "Standard"
# silhueta ao girar: quanto o meio (esquerda+direita)/2 de cada trecho anda, em % da largura
sil = []
for o, turns in spin:
    mids, wid = [], 0
    for q in range(48):
        a = 2 * math.pi * q / 48; xs = [v.co.x * math.cos(a) - v.co.y * math.sin(a) for v in o.data.vertices]
        mids.append((max(xs) + min(xs)) / 2); wid = max(wid, max(xs) - min(xs))
    sil.append((o.name, round((max(mids) - min(mids)) / wid * 100, 1)))
result = {"silhueta_anda_%": sil, "balance_%_do_raio": report, "tris": sum(o.get("tris", 0) for o in sc.objects)}
