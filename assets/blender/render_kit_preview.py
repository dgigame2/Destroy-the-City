# Prévia de como os modelos do jogo ficam com o kit do Blender (DioramaKit.blend), com as cores do mapa.
# Uso: lune run kitpreview GardenVillage
#      blender -b --factory-startup --python assets/blender/render_kit_preview.py -- GardenVillage
# Saída: assets/preview/kit_<Id>.png
# Eixos: Roblox (x, y, z) -> Blender (x, -z, y)  (Roblox Y = cima; frente -Z do Roblox = +Y do Blender).

import bpy
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
map_id = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "GardenVillage"
data = json.load(open(os.path.join(ROOT, "assets", "preview", f"kit_{map_id}.json"), encoding="utf-8"))

bpy.ops.wm.open_mainfile(filepath=os.path.join(HERE, "DioramaKit.blend"))
scene = bpy.context.scene
kit = {o.name: o for o in bpy.data.objects}
for o in kit.values():
    o.hide_render = True

materials = {}


def material(rgb, role):
    key = (tuple(rgb), role)
    if key not in materials:
        m = bpy.data.materials.new(f"{role}_{rgb[0]}_{rgb[1]}_{rgb[2]}")
        m.use_nodes = True
        bsdf = m.node_tree.nodes["Principled BSDF"]
        bsdf.inputs["Base Color"].default_value = (*(pow(c / 255, 2.2) for c in rgb), 1)
        bsdf.inputs["Roughness"].default_value = 0.75
        if role == "Light":
            bsdf.inputs["Emission Color"].default_value = (*(pow(c / 255, 2.2) for c in rgb), 1)
            bsdf.inputs["Emission Strength"].default_value = 2.0
        materials[key] = m
    return materials[key]


def plain(shape):
    if shape == "Cylinder":
        bpy.ops.mesh.primitive_cylinder_add(vertices=14, radius=0.5, depth=1)
    elif shape == "Ball":
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.5)
    elif shape == "Wedge":
        bpy.ops.mesh.primitive_cube_add(size=1)
        obj = bpy.context.active_object
        # cunha: parte alta em +Z do Roblox = +Y do Blender; corta o topo do lado -Y
        for v in obj.data.vertices:
            if v.co.z > 0 and v.co.y < 0:
                v.co.z = -0.5
        return obj
    else:
        bpy.ops.mesh.primitive_cube_add(size=1)
    return bpy.context.active_object


count = 0
for item in data["Items"]:
    name = item["Kit"]
    if name and name in kit:
        obj = kit[name].copy()
        obj.data = kit[name].data
        obj.hide_render = False
        scene.collection.objects.link(obj)
    else:
        obj = plain(item["Shape"])
    x, y, z = item["Pos"]
    sx, sy, sz = item["Size"]
    obj.location = (x, -z, y)
    if item["Shape"] == "Wedge" and item["Rot"] in (90, 270):
        obj.scale = (sz, sx, sy)
    else:
        obj.scale = (sx, sz, sy)
    if item["Shape"] == "Wedge":
        angle = {0: 0, 90: -90, 180: 180, 270: 90}.get(int(item["Rot"]), 0)
        obj.rotation_euler = (0, 0, math.radians(-angle))
    obj.data.materials.clear() if obj.data.users == 1 else None
    if obj.data.users > 1:
        obj.material_slots and None
    obj.active_material = None
    if len(obj.material_slots) == 0:
        obj.data.materials.append(None) if obj.data.users == 1 else None
    if len(obj.material_slots) > 0:
        obj.material_slots[0].link = "OBJECT"
        obj.material_slots[0].material = material(item["Color"], item["Role"])
    else:
        obj.data.materials.append(material(item["Color"], item["Role"]))
    count += 1

# kit compartilha a mesh: garante 1 slot por objeto (link = OBJECT) para cada cópia ter a sua cor
for o in kit.values():
    if len(o.data.materials) == 0:
        o.data.materials.append(None)

width = data["Width"]
bpy.ops.mesh.primitive_plane_add(size=1, location=(width / 2, 4, -0.05))
ground = bpy.context.active_object
ground.scale = (width + 40, 60, 1)
ground.data.materials.append(material([104, 214, 64], "Ground"))

cam_data = bpy.data.cameras.new("Cam")
cam = bpy.data.objects.new("Cam", cam_data)
scene.collection.objects.link(cam)
cam_data.type = "ORTHO"
cam_data.ortho_scale = width * 1.02
# frente dos modelos = -Z do Roblox = +Y do Blender: a câmera fica do lado +Y olhando para -Y
cam.location = (width / 2, width * 0.5, width * 0.62)
cam.rotation_euler = (math.radians(44), 0, math.radians(180))
scene.camera = cam

sun_data = bpy.data.lights.new("Sun", "SUN")
sun_data.energy = 3.0
sun_data.angle = math.radians(8)
sun = bpy.data.objects.new("Sun", sun_data)
sun.rotation_euler = (math.radians(48), math.radians(12), math.radians(30))
scene.collection.objects.link(sun)
world = bpy.data.worlds.new("Sky")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.55, 0.75, 1.0, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 1.0
scene.world = world
scene.view_settings.view_transform = "Standard"
engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
scene.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in engines else "BLENDER_EEVEE"
scene.render.resolution_x = 1800
scene.render.resolution_y = 700
scene.render.filepath = os.path.join(ROOT, "assets", "preview", f"kit_{map_id}.png")
bpy.ops.render.render(write_still=True)
print(f"prévia: {count} blocos")
