# Cogumelo de enfeite do lobby (low-poly, faces chapadas): chapéu vermelho facetado com bolinhas brancas
# hexagonais e pé creme.
# Uso: blender -b --factory-startup --python assets/blender/build_mushroom.py
# Saída (assets/blender/): Mushroom.fbx (mesh "Lobby_Mushroom"; importe em ReplicatedStorage.Assets),
#   MushroomPalette.png, Mushroom.blend, mushroom_preview.png, mushroom_size.txt (vai para LobbyConfig.Props)
# Convenções iguais ao build_lobby.py: 1 unidade = 1 stud, origem no centro da base, Z do Blender = Y do Roblox.

import bpy
import bmesh
import math
import os

from mathutils import Vector

OUT = os.path.dirname(os.path.abspath(__file__))
COLORS = {
    "Cap": (226, 40, 52),
    "CapDark": (190, 28, 42),
    "Spot": (246, 248, 255),
    "Stem": (238, 214, 186),
    "Gill": (226, 204, 178),
    "GillDark": (196, 168, 138),
}
NAMES = list(COLORS)

CAP_R = 1.7  # raio do chapéu
CAP_H = 1.5  # altura do chapéu
STEM_H = 1.0  # altura do pé até a aba do chapéu
SEG = 9  # facetas em volta (ímpar: fica com cara de "feito à mão")


def palette_image():
    size = 4 * len(NAMES)
    img = bpy.data.images.new("MushroomPalette", size, 4, alpha=False)
    px = []
    for _y in range(4):
        for x in range(size):
            r, g, b = (c / 255 for c in COLORS[NAMES[x // 4]])
            px += [r, g, b, 1.0]
    img.pixels = px
    img.filepath_raw = os.path.join(OUT, "MushroomPalette.png")
    img.file_format = "PNG"
    img.save()
    return img


def paint(bm, uv, face, color):
    u = (NAMES.index(color) + 0.5) / len(NAMES)
    for loop in face.loops:
        loop[uv].uv = (u, 0.5)


def build():
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")

    base_z = STEM_H + 0.2  # aba do chapéu
    gill_z = base_z + 0.32  # onde o pé encontra o fundo do chapéu
    stem_top = 0.45

    # pé: 8 lados, mais gordinho embaixo, afinando até encostar no fundo do chapéu (sem buraco)
    SIDES = 8
    profile = [(0.0, 0.7), (0.25, 0.66), (STEM_H * 0.6, 0.5), (gill_z, stem_top)]
    stem = [
        [bm.verts.new((math.cos(a) * r, math.sin(a) * r, z)) for a in (k / SIDES * math.tau for k in range(SIDES))]
        for z, r in profile
    ]
    paint(bm, uv, bm.faces.new(list(reversed(stem[0]))), "Stem")
    for i in range(len(stem) - 1):
        for k in range(SIDES):
            k2 = (k + 1) % SIDES
            paint(bm, uv, bm.faces.new((stem[i][k], stem[i][k2], stem[i + 1][k2], stem[i + 1][k])), "Stem")

    # chapéu: meia esfera facetada (anéis desencontrados = facetas triangulares como na referência)
    rings = [(1.0, 0.0), (0.96, 0.3), (0.8, 0.62), (0.46, 0.88), (0.0, 1.0)]  # (raio, altura) relativos
    cap = []
    for i, (rr, zz) in enumerate(rings):
        if rr == 0:
            cap.append([bm.verts.new((0, 0, base_z + zz * CAP_H))])
            continue
        twist = (i % 2) * (math.pi / SEG)
        cap.append(
            [
                bm.verts.new((math.cos(a) * rr * CAP_R, math.sin(a) * rr * CAP_R, base_z + zz * CAP_H))
                for a in (k / SEG * math.tau + twist for k in range(SEG))
            ]
        )
    cap_faces = []
    for i in range(len(cap) - 1):
        a, b = cap[i], cap[i + 1]
        color = "CapDark" if i == 0 else "Cap"
        for k in range(SEG):
            k2 = (k + 1) % SEG
            tris = ((a[k], a[k2], b[0]),) if len(b) == 1 else ((a[k], a[k2], b[k2]), (a[k], b[k2], b[k]))
            for tri in tris:
                f = bm.faces.new(tri)
                paint(bm, uv, f, color)
                cap_faces.append(f)

    # fundo do chapéu: da aba sobe em degrau até o topo do pé, com lamelas (faixas claras/escuras)
    mid = [
        bm.verts.new((math.cos(a) * CAP_R * 0.72, math.sin(a) * CAP_R * 0.72, base_z + 0.2))
        for a in (k / SEG * math.tau for k in range(SEG))
    ]
    for k in range(SEG):
        k2 = (k + 1) % SEG
        paint(bm, uv, bm.faces.new((cap[0][k2], cap[0][k], mid[k], mid[k2])), "Gill")
    # anel de dentro: costura o anel do meio (SEG pontos) no topo do pé (SIDES pontos) andando pelo ângulo
    i = j = 0
    count = 0
    while i < SEG or j < SIDES:
        a_next = (i + 1) / SEG if i < SEG else 9
        b_next = (j + 1) / SIDES if j < SIDES else 9
        m0, s0 = mid[i % SEG], stem[-1][j % SIDES]
        if a_next <= b_next:
            tri = (mid[(i + 1) % SEG], m0, s0)
            i += 1
        else:
            tri = (stem[-1][(j + 1) % SIDES], m0, s0)
            j += 1
        paint(bm, uv, bm.faces.new(tri), "Gill" if count % 2 == 0 else "GillDark")
        count += 1
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)

    # bolinhas: prismas hexagonais assentados na faceta do chapéu (acha a faceta por raio a partir do centro)
    bm.faces.ensure_lookup_table()
    from mathutils.bvhtree import BVHTree

    tree = BVHTree.FromBMesh(bm)
    origin = Vector((0, 0, gill_z + 0.05))  # acima do pé: o raio só bate no chapéu
    spots = [(0.0, 0.92, 0.3), (0.9, 0.6, 0.26), (2.2, 0.64, 0.28), (3.4, 0.58, 0.24), (4.6, 0.62, 0.27),
             (5.7, 0.56, 0.22), (1.5, 0.28, 0.2), (3.0, 0.26, 0.21), (4.1, 0.3, 0.19), (5.2, 0.26, 0.2), (0.3, 0.27, 0.18)]
    for ang, lat, size in spots:
        phi = lat * math.pi / 2
        d = Vector((math.cos(ang) * math.cos(phi), math.sin(ang) * math.cos(phi), math.sin(phi)))
        hit, normal, _index, _dist = tree.ray_cast(origin, d)
        if hit is None:
            continue
        n = normal.normalized()
        if n.dot(d) < 0:
            n = -n
        t = n.cross(Vector((0, 0, 1)))
        if t.length < 0.1:
            t = Vector((1, 0, 0))
        t.normalize()
        b = n.cross(t)
        top, low = [], []
        for k in range(6):
            a = k / 6 * math.tau
            p = hit + t * (math.cos(a) * size) + b * (math.sin(a) * size)
            top.append(bm.verts.new(p + n * 0.05))
            low.append(bm.verts.new(p - n * 0.05))  # entra um pouco no chapéu: não flutua em nenhum ângulo
        paint(bm, uv, bm.faces.new(top), "Spot")
        paint(bm, uv, bm.faces.new(list(reversed(low))), "Spot")
        for k in range(6):
            k2 = (k + 1) % 6
            paint(bm, uv, bm.faces.new((low[k], low[k2], top[k2], top[k])), "Spot")
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)

    mesh = bpy.data.meshes.new("Lobby_Mushroom")
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new("Lobby_Mushroom", mesh)
    bpy.context.scene.collection.objects.link(obj)
    for p in mesh.polygons:
        p.use_smooth = False  # facetado
    return obj


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    img = palette_image()
    mat = bpy.data.materials.new("MushroomPalette")
    mat.use_nodes = True
    tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Closest"
    mat.node_tree.links.new(tex.outputs["Color"], mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"])
    obj = build()
    obj.data.materials.append(mat)

    xs = [v.co.x for v in obj.data.vertices]
    ys = [v.co.y for v in obj.data.vertices]
    zs = [v.co.z for v in obj.data.vertices]
    size = (max(xs) - min(xs), max(zs) - min(zs), max(ys) - min(ys))  # Roblox X, Y, Z
    center = ((max(xs) + min(xs)) / 2, (max(zs) + min(zs)) / 2, -(max(ys) + min(ys)) / 2)
    tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    info = (
        f"Lobby_Mushroom: {tris} tris | Size = {{ {size[0]:.2f}, {size[1]:.2f}, {size[2]:.2f} }}, "
        f"Center = {{ {center[0]:.2f}, {center[1]:.2f}, {center[2]:.2f} }}"
    )
    with open(os.path.join(OUT, "mushroom_size.txt"), "w", encoding="utf-8") as f:
        f.write(info + "\n")
    print(info)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "Mushroom.blend"))

    try:
        scene = bpy.context.scene
        scene.render.engine = "BLENDER_EEVEE"
        world = bpy.data.worlds.new("w")
        world.use_nodes = True
        world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.45, 0.6, 0.8, 1)
        world.node_tree.nodes["Background"].inputs["Strength"].default_value = 1.2
        scene.world = world
        scene.render.resolution_x = scene.render.resolution_y = 600
        cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
        scene.collection.objects.link(cam)
        cam.location = (0, -8, 3.4)
        cam.rotation_euler = (math.radians(75), 0, 0)
        scene.camera = cam
        sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
        sun.data.energy = 4
        sun.rotation_euler = (math.radians(45), 0, math.radians(30))
        scene.collection.objects.link(sun)
        scene.render.filepath = os.path.join(OUT, "mushroom_preview.png")
        bpy.ops.render.render(write_still=True)
        # visto de baixo (como o jogador vê de perto)
        cam.location = (0, -5.5, 0.5)
        cam.rotation_euler = (math.radians(95), 0, 0)
        scene.render.filepath = os.path.join(OUT, "mushroom_preview_low.png")
        bpy.ops.render.render(write_still=True)
        for o in (cam, sun):
            bpy.data.objects.remove(o, do_unlink=True)
    except Exception as err:
        print("preview falhou:", err)

    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(OUT, "Mushroom.fbx"),
        use_selection=True,
        object_types={"MESH"},
        axis_forward="-Z",
        axis_up="Y",
        apply_scale_options="FBX_SCALE_ALL",
        mesh_smooth_type="FACE",
        path_mode="COPY",
        embed_textures=True,
        add_leaf_bones=False,
        bake_anim=False,
    )
    print("Mushroom pronto")


main()
