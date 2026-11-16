# Gera as meshes do jogo no Blender (estilo "Diorama" dos mapas: low-poly, cantos chanfrados, liso).
# Uso (sem abrir a tela do Blender):
#   blender -b --factory-startup --python assets/blender/build_kit.py
# Saída (assets/blender/):
#   DioramaKit.fbx   -> peças do kit (Kit_Block, Kit_Leaf, Kit_Cylinder, Kit_Ball) + desastres
#                       (Meteor, TornadoFunnel, StormCloud). Importe no Studio em ReplicatedStorage.Assets.
#   DioramaKit.blend -> arquivo editável
#   kit_preview.png  -> render de conferência
#   kit_stats.txt    -> triângulos e tamanho de cada mesh
#
# Regras do kit (o Builder escala cada peça para o tamanho do bloco do Template):
# - Peças do kit: caixa envolvente EXATAMENTE 1x1x1, centrada na origem. Assim Size do bloco = Size da mesh.
# - Sem textura: a cor vem do MeshPart.Color (paleta do mapa), então variantes de cor continuam funcionando.
# - Eixos: Blender Z = Roblox Y (cima). Blender +Y = Roblox +Z (exportado com forward -Z, up Y).

import bpy
import bmesh
import math
import os
import random

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)))
random.seed(7)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def new_object(name, bm):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def apply_modifiers(obj):
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    for mod in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=mod.name)
    obj.select_set(False)


def shade_flat_with_soft_bevels(obj):
    # low-poly: faces planas (o visual dos mapas), mas normais suaves nos chanfros pequenos
    for poly in obj.data.polygons:
        poly.use_smooth = False


def fit_unit_box(obj):
    # escala/centraliza para a caixa envolvente ficar exatamente 1x1x1 na origem
    xs = [v.co.x for v in obj.data.vertices]
    ys = [v.co.y for v in obj.data.vertices]
    zs = [v.co.z for v in obj.data.vertices]
    cx, cy, cz = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2, (min(zs) + max(zs)) / 2
    sx, sy, sz = max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs)
    for v in obj.data.vertices:
        v.co.x = (v.co.x - cx) / sx
        v.co.y = (v.co.y - cy) / sy
        v.co.z = (v.co.z - cz) / sz


def fit_box(obj, size):
    fit_unit_box(obj)
    for v in obj.data.vertices:
        v.co.x *= size[0]
        v.co.y *= size[1]
        v.co.z *= size[2]


def bevel(obj, width, segments):
    mod = obj.modifiers.new("Bevel", "BEVEL")
    mod.width = width
    mod.segments = segments
    mod.limit_method = "ANGLE"
    mod.angle_limit = math.radians(40)
    mod.harden_normals = False
    apply_modifiers(obj)


# --- Kit das construções -----------------------------------------------------------------


def kit_block():
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    obj = new_object("Kit_Block", bm)
    bevel(obj, 0.07, 2)  # cantos macios como nos mapas; 2 segmentos = barato e redondinho
    fit_unit_box(obj)
    return obj


def kit_cylinder():
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=14, radius1=0.5, radius2=0.5, depth=1.0)
    obj = new_object("Kit_Cylinder", bm)
    bevel(obj, 0.05, 2)
    fit_unit_box(obj)
    return obj


def kit_ball():
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=2, radius=0.5)
    obj = new_object("Kit_Ball", bm)
    fit_unit_box(obj)
    return obj


def kit_leaf():
    # folhagem low-poly: icosfera achatada com os vértices levemente deslocados (copa "fofinha")
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=2, radius=0.5)
    for v in bm.verts:
        n = v.co.normalized()
        bump = 1.0 + random.uniform(-0.07, 0.07)
        v.co = n * 0.5 * bump
        if v.co.z < -0.2:  # base mais reta: a copa assenta no galho/camada de baixo
            v.co.z = -0.2 - (v.co.z + 0.2) * 0.35
    obj = new_object("Kit_Leaf", bm)
    fit_unit_box(obj)
    return obj


# --- Desastres ---------------------------------------------------------------------------


def meteor():
    # pedra low-poly irregular (as rachaduras de lava ficam por conta do Fire/PointLight do jogo)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=2, radius=0.5)
    for v in bm.verts:
        v.co = v.co.normalized() * 0.5 * random.uniform(0.82, 1.12)
    obj = new_object("Meteor", bm)
    fit_unit_box(obj)
    return obj


def tornado_funnel():
    # funil torcido: anéis empilhados, cada um mais largo e girado (lê como redemoinho mesmo parado)
    bm = bmesh.new()
    rings, segments = 9, 12
    loops = []
    for i in range(rings + 1):
        t = i / rings
        radius = 0.08 + 0.42 * (t ** 1.6)
        z = t
        twist = t * math.radians(150)
        wobble = 0.04 * math.sin(t * math.pi * 3)
        loop = []
        for s in range(segments):
            a = s / segments * math.tau + twist
            loop.append(bm.verts.new((math.cos(a) * radius + wobble, math.sin(a) * radius, z)))
        loops.append(loop)
    for i in range(rings):
        for s in range(segments):
            a, b = loops[i][s], loops[i][(s + 1) % segments]
            c, d = loops[i + 1][(s + 1) % segments], loops[i + 1][s]
            bm.faces.new((a, b, c, d))
    bm.faces.new(list(reversed(loops[0])))
    bm.faces.new(loops[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj = new_object("TornadoFunnel", bm)
    fit_unit_box(obj)
    return obj


def storm_cloud():
    # nuvem fofa de tempestade: várias bolas low-poly unidas (sem uma entrar na outra visivelmente)
    bm = bmesh.new()
    puffs = [
        (0.0, 0.0, 0.05, 0.42),
        (0.45, 0.05, 0.0, 0.32),
        (-0.45, -0.05, 0.0, 0.34),
        (0.15, 0.3, 0.1, 0.3),
        (-0.2, -0.3, 0.08, 0.3),
        (0.75, -0.1, -0.05, 0.22),
        (-0.78, 0.1, -0.05, 0.22),
    ]
    for x, y, z, r in puffs:
        ret = bmesh.ops.create_icosphere(bm, subdivisions=1, radius=r)
        for v in ret["verts"]:
            v.co.x += x
            v.co.y += y
            v.co.z = z + v.co.z * 0.7
    obj = new_object("StormCloud", bm)
    fit_box(obj, (2.4, 1.6, 0.9))
    return obj


def stats(objs):
    lines = []
    for obj in objs:
        tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
        d = obj.dimensions
        lines.append(f"{obj.name}: {tris} tris, caixa {d.x:.3f} x {d.y:.3f} x {d.z:.3f}")
    return lines


def preview(objs):
    # render rápido de conferência: cada peça lado a lado, cores da paleta Diorama
    colors = {
        "Kit_Block": (1.0, 0.85, 0.62, 1),
        "Kit_Leaf": (0.33, 0.78, 0.25, 1),
        "Kit_Cylinder": (0.56, 0.82, 1.0, 1),
        "Kit_Ball": (1.0, 0.55, 0.5, 1),
        "Meteor": (0.25, 0.2, 0.22, 1),
        "TornadoFunnel": (0.78, 0.82, 0.9, 1),
        "StormCloud": (0.55, 0.6, 0.72, 1),
    }
    scene = bpy.context.scene
    scene.view_settings.view_transform = "Standard"  # cores da paleta sem lavar
    for obj in objs:
        obj.hide_render = True
    copies = []
    for i, obj in enumerate(objs):
        c = obj.copy()
        c.data = obj.data.copy()
        c.hide_render = False
        scene.collection.objects.link(c)
        c.location = (i * 2.2 - (len(objs) - 1) * 1.1, 0, 0.6)
        if obj.name == "TornadoFunnel":
            c.scale = (1, 1, 1.8)
            c.location.z = 1.0
        mat = bpy.data.materials.new(obj.name + "_Preview")
        mat.diffuse_color = colors.get(obj.name, (1, 1, 1, 1))
        mat.use_nodes = True
        mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = mat.diffuse_color
        mat.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.8
        c.data.materials.append(mat)
        copies.append(c)
    bpy.ops.mesh.primitive_plane_add(size=40, location=(0, 0, 0.1 - 0.5 + 0.0))
    ground = bpy.context.active_object
    gmat = bpy.data.materials.new("Ground")
    gmat.use_nodes = True
    gmat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.42, 0.8, 0.28, 1)
    ground.data.materials.append(gmat)
    ground.location.z = 0.1
    cam_data = bpy.data.cameras.new("Cam")
    cam = bpy.data.objects.new("Cam", cam_data)
    scene.collection.objects.link(cam)
    cam.location = (0, -14, 6.5)
    cam.rotation_euler = (math.radians(68), 0, 0)
    cam_data.lens = 30
    scene.camera = cam
    sun_data = bpy.data.lights.new("Sun", "SUN")
    sun_data.energy = 3.2
    sun_data.angle = math.radians(12)
    sun = bpy.data.objects.new("Sun", sun_data)
    sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(35))
    scene.collection.objects.link(sun)
    world = bpy.data.worlds.new("Sky")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.72, 0.86, 1.0, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.9
    scene.world = world
    scene.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in [
        e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items
    ] else "BLENDER_EEVEE"
    scene.render.resolution_x = 1400
    scene.render.resolution_y = 520
    scene.render.filepath = os.path.join(OUT, "kit_preview.png")
    bpy.ops.render.render(write_still=True)
    for c in copies + [ground, cam, sun]:
        bpy.data.objects.remove(c, do_unlink=True)


def main():
    reset()
    objs = [kit_block(), kit_leaf(), kit_cylinder(), kit_ball(), meteor(), tornado_funnel(), storm_cloud()]
    for obj in objs:
        shade_flat_with_soft_bevels(obj)
    with open(os.path.join(OUT, "kit_stats.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(stats(objs)) + "\n")
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "DioramaKit.blend"))
    try:
        preview(objs)
    except Exception as err:  # o render é só conferência; o FBX é o que importa
        print("preview falhou:", err)
    for obj in objs:
        obj.hide_render = False
    for obj in bpy.data.objects:
        obj.select_set(obj in objs)
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(OUT, "DioramaKit.fbx"),
        use_selection=True,
        object_types={"MESH"},
        axis_forward="-Z",
        axis_up="Y",
        apply_scale_options="FBX_SCALE_ALL",
        mesh_smooth_type="FACE",
        add_leaf_bones=False,
        bake_anim=False,
    )
    print("DioramaKit pronto:", ", ".join(o.name for o in objs))


main()
