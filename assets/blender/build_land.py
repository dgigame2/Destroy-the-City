# Terreno redondo em volta da cidade do lobby + tulipas avulsas para espalhar no gramado do parque.
#   Lobby_Land        -> chão plano (altura 0) que começa no retângulo do gramado da cidade (buraco), vai até um
#                        contorno redondo ondulado e desce suave numa "saia" (a borda do mundo some no horizonte).
#                        Usa o material de grama do lobby (sem textura própria).
#   Lobby_TulipRed    -> 3 tulipas vermelhas avulsas (mesmo modelo das floreiras, mesma textura PlanterAtlas)
#   Lobby_TulipPink   -> 3 tulipas cor-de-rosa
# Uso: lune run land  e depois  blender -b --factory-startup --python assets/blender/build_land.py
# Saída (assets/blender/): Land.fbx, land_sizes.txt (vai para LobbyConfig.Props), land_preview.png
# Convenções: 1 unidade = 1 stud, Z do Blender = Y do Roblox, Roblox Z = -Y do Blender.

import bpy
import bmesh
import json
import math
import os
import sys

OUT = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, OUT)
import build_nature as bn  # noqa: E402  (Mesh com as tulipas e o atlas das floreiras)

with open(os.path.join(OUT, "land_layout.json"), encoding="utf-8") as f:
    L = json.load(f)


def land():
    hx, hz = L["HoleX"], L["HoleZ"]
    R, wob, skirt, drop = L["Radius"], L["Wobble"], L["Skirt"], L["Drop"]
    # ângulos: uniformes + as 4 quinas do retângulo (o contorno de dentro bate certinho no gramado)
    corner = math.atan2(hz, hx)
    angles = sorted({i / 160 * math.tau for i in range(160)} | {corner, math.pi - corner, math.pi + corner, math.tau - corner})

    def inner(a):
        c, s = math.cos(a), math.sin(a)
        t = min(hx / abs(c) if abs(c) > 1e-9 else 1e9, hz / abs(s) if abs(s) > 1e-9 else 1e9)
        return c * t, s * t

    def outer_r(a):
        return R + wob * (0.6 * math.sin(3 * a + 1) + 0.4 * math.sin(5 * a + 2))

    rings = []
    flat = 8  # anéis entre o buraco e o contorno (chão plano)
    for k in range(flat + 1):
        t = k / flat
        ring = []
        for a in angles:
            ix, iz = inner(a)
            r = outer_r(a)
            ox, oz = math.cos(a) * r, math.sin(a) * r
            ring.append((ix + (ox - ix) * t, iz + (oz - iz) * t, 0.0))
        rings.append(ring)
    for k in range(1, 7):  # saia: desce suave
        s = k / 6
        ring = []
        for a in angles:
            r = outer_r(a) + skirt * s
            ring.append((math.cos(a) * r, math.sin(a) * r, -drop * (s * s * (3 - 2 * s))))
        rings.append(ring)

    bm = bmesh.new()
    # Roblox Z = -Y do Blender: grava (x, -z) no plano do Blender
    verts = [[bm.verts.new((p[0], -p[1], p[2])) for p in ring] for ring in rings]
    n = len(angles)
    for k in range(len(verts) - 1):
        for i in range(n):
            i2 = (i + 1) % n
            bm.faces.new((verts[k][i], verts[k + 1][i], verts[k + 1][i2], verts[k][i2]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    # normais para cima (é um chão)
    for f in bm.faces:
        f.normal_update()
        if f.normal.z < 0:
            f.normal_flip()
    mesh = bpy.data.meshes.new("Lobby_Land")
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new("Lobby_Land", mesh)
    bpy.context.scene.collection.objects.link(obj)
    for p in mesh.polygons:
        p.use_smooth = True
    return obj


def tulips(name, pink, mat):
    m = bn.Mesh()
    for i, (x, y) in enumerate(((0.0, 0.35), (-0.35, -0.2), (0.38, -0.25))):
        m.tulip(x, y, 0.0, 0.8 + 0.12 * i, pink, i * 1.7 + (0.5 if pink else 0))
    return m.finish(name, mat)


def size_line(obj):
    xs = [v.co.x for v in obj.data.vertices]
    ys = [v.co.y for v in obj.data.vertices]
    zs = [v.co.z for v in obj.data.vertices]
    size = (max(xs) - min(xs), max(zs) - min(zs), max(ys) - min(ys))
    center = ((max(xs) + min(xs)) / 2, (max(zs) + min(zs)) / 2, -(max(ys) + min(ys)) / 2)
    tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    return (
        f"{obj.name}: {tris} tris | Size = {{ {size[0]:.2f}, {size[1]:.2f}, {size[2]:.2f} }}, "
        f"Center = {{ {center[0]:.2f}, {center[1]:.2f}, {center[2]:.2f} }}"
    )


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    atlas = bn.planter_atlas()
    mat = bpy.data.materials.new("PlanterAtlas")
    mat.use_nodes = True
    tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = atlas
    mat.node_tree.links.new(tex.outputs["Color"], mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"])
    objs = [land(), tulips("Lobby_TulipRed", False, mat), tulips("Lobby_TulipPink", True, mat)]
    lines = [size_line(o) for o in objs]
    with open(os.path.join(OUT, "land_sizes.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print("\n".join(lines))
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "Land.blend"))
    try:
        scene = bpy.context.scene
        world = bpy.data.worlds.new("w")
        world.use_nodes = True
        world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.45, 0.6, 0.8, 1)
        scene.world = world
        scene.render.engine = "BLENDER_EEVEE"
        scene.render.resolution_x, scene.render.resolution_y = 800, 800
        objs[1].hide_render = objs[2].hide_render = True
        cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
        cam.data.clip_end = 5000
        scene.collection.objects.link(cam)
        cam.location = (0, 0, 2600)
        scene.camera = cam
        sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
        sun.data.energy = 4
        scene.collection.objects.link(sun)
        scene.render.filepath = os.path.join(OUT, "land_preview.png")
        bpy.ops.render.render(write_still=True)
        objs[1].hide_render = objs[2].hide_render = False
        for o in (cam, sun):
            bpy.data.objects.remove(o, do_unlink=True)
    except Exception as err:
        print("preview falhou:", err)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(OUT, "Land.fbx"),
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
    print("Land pronto")


main()
