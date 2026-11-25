# Peças comuns dos scripts de modelo: formas chanfradas, junção por papel de cor, GLB e prévia.
# Unidades em studs, base em z=0, frente para -Y.
import bpy, bmesh, math
from mathutils import Matrix, Vector

parts = {}
mats = {}


def lin(c):
    c /= 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def lerp(a, b, t):
    return a + (b - a) * t


def material(name, rgb, rough=0.55):
    mt = bpy.data.materials.new(name)
    mt.use_nodes = True
    bs = mt.node_tree.nodes["Principled BSDF"]
    bs.inputs["Base Color"].default_value = (*[lin(c) for c in rgb], 1)
    bs.inputs["Roughness"].default_value = rough
    return mt


def setup(colors):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    mats.clear()
    for role, rgb in colors.items():
        mats[role] = material(role, rgb)


def begin():
    parts.clear()


# smooth = superfície lisa (frutas); flat = facetado sem suavizar o chanfro
def obj(role, verts, faces, bevel=0.07, seg=1, flat=False, smooth=False):
    me = bpy.data.meshes.new(role)
    me.from_pydata([tuple(v) for v in verts], [], faces)
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(role, me)
    bpy.context.scene.collection.objects.link(o)
    me.materials.append(mats[role])
    for p in me.polygons:
        p.use_smooth = (smooth or bool(bevel)) and not flat
    if bevel:
        md = o.modifiers.new("b", "BEVEL")
        md.width = bevel
        md.segments = seg
        md.limit_method = "ANGLE"
        md.angle_limit = math.radians(9)
        md.harden_normals = not flat
    parts.setdefault(role, []).append(o)
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


# z = base; top = escala do topo
def box(role, x, y, z, sx, sy, sz, top=1.0, **kw):
    def r(k, zz):
        a, b = sx / 2 * k, sy / 2 * k
        return [(x - a, y - b, zz), (x + a, y - b, zz), (x + a, y + b, zz), (x - a, y + b, zz)]
    return loft(role, [r(1, z), r(top, z + sz)], **kw)


# polígono (y, z) puxado em x
def prism_x(role, poly, x0, x1, **kw):
    return loft(role, [[(x, y, z) for y, z in poly] for x in (x0, x1)], **kw)


# tubo por pontos, com raio por ponto
def tube(role, pts, radii, n=8, **kw):
    rings = []
    for i, p in enumerate(pts):
        d = (Vector(pts[min(i + 1, len(pts) - 1)]) - Vector(pts[max(i - 1, 0)])).normalized()
        side = d.cross(Vector((0.3, 1, 0.1))).normalized()
        up = d.cross(side)
        rings.append([Vector(p) + (side * math.cos(2 * math.pi * k / n) + up * math.sin(2 * math.pi * k / n)) * radii[i] for k in range(n)])
    return loft(role, rings, **kw)


# contornos (x, z) fechados, com furos, virados para -Y: placas e letras. y = face da frente, thick = espessura
def shape(role, outlines, y, thick, bevel=.03):
    cu = bpy.data.curves.new(role, "CURVE")
    cu.dimensions = "2D"
    cu.fill_mode = "BOTH"
    cu.extrude = thick / 2 - bevel
    cu.bevel_depth = bevel
    cu.bevel_resolution = 0
    cu.offset = -bevel
    for pts in outlines:
        sp = cu.splines.new("POLY")
        sp.points.add(len(pts) - 1)
        for p, (x, z) in zip(sp.points, pts):
            p.co = (x, z, 0, 1)
        sp.use_cyclic_u = True
    tmp = bpy.data.objects.new(role, cu)
    bpy.context.scene.collection.objects.link(tmp)
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(tmp.evaluated_get(dg))
    bpy.data.objects.remove(tmp)
    me.transform(Matrix.Translation((0, y + thick / 2, 0)) @ Matrix.Rotation(math.pi / 2, 4, "X"))
    me.materials.clear()
    me.materials.append(mats[role])
    for p in me.polygons:
        p.use_smooth = False
    o = bpy.data.objects.new(role, me)
    bpy.context.scene.collection.objects.link(o)
    parts.setdefault(role, []).append(o)
    return o


# junta por papel; devolve as meshes e mostra triângulos e o Size/Center do MeshModelsConfig
def finish(name):
    meshes = []
    total = 0
    for role, group in parts.items():
        bpy.ops.object.select_all(action="DESELECT")
        for o in group:
            o.select_set(True)
            bpy.context.view_layer.objects.active = o
        bpy.ops.object.convert(target="MESH")
        bpy.ops.object.join()
        o = bpy.context.view_layer.objects.active
        o.name = o.data.name = f"M_{name}_{role}"
        o.data.calc_loop_triangles()
        total += len(o.data.loop_triangles)
        c0 = [min(v.co[i] for v in o.data.vertices) for i in range(3)]
        c1 = [max(v.co[i] for v in o.data.vertices) for i in range(3)]
        size = [c1[i] - c0[i] for i in range(3)]
        mid = [(c1[i] + c0[i]) / 2 for i in range(3)]
        # o Roblox recebe (-x, z, y): mesmo giro de 180 que o export faz
        print("PIECE", role, o.name, len(o.data.loop_triangles), "{ %.3f, %.3f, %.3f }" % (size[0], size[2], size[1]),
              "{ %.3f, %.3f, %.3f }" % (-mid[0], mid[2], mid[1]))
        meshes.append(o)
    print("TOTAL", name, total)
    return meshes


def export(meshes, path):
    turn = Matrix.Rotation(math.pi, 4, "Z")
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.data.transform(turn)
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, use_selection=True)
    for o in meshes:
        o.data.transform(turn)


def stage(ground, res=(1492, 1054)):
    scene = bpy.context.scene
    bpy.ops.mesh.primitive_plane_add(size=400)
    bpy.context.object.data.materials.append(material("chao", ground, 1))
    bpy.context.object.visible_diffuse = False  # sem reflexo da cor do chão no modelo
    sun = bpy.data.objects.new("s", bpy.data.lights.new("s", "SUN"))
    scene.collection.objects.link(sun)
    sun.data.energy = 2.3
    sun.data.angle = .12
    sun.rotation_euler = (math.radians(38), math.radians(20), math.radians(-25))
    w = bpy.data.worlds.new("w")
    scene.world = w
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (.86, .9, 1, 1)
    w.node_tree.nodes["Background"].inputs[1].default_value = .55
    cam = bpy.data.objects.new("c", bpy.data.cameras.new("c"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    cam.data.lens = 60
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 48
    scene.cycles.use_denoising = True
    scene.render.resolution_x, scene.render.resolution_y = res
    scene.view_settings.view_transform = "Standard"


def shot(path, pos, look):
    cam = bpy.context.scene.camera
    cam.location = pos
    cam.rotation_euler = (Vector(look) - Vector(pos)).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
