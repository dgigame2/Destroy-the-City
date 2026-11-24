"""Generate the editable Level 4 Tornado and its game exports in Blender 5.2.

blender -b --factory-startup --python generate_tornado.py
Outputs are written next to this script. Run in an isolated Blender process.
"""
from math import cos, pi, radians, sin, tau
from pathlib import Path
from random import Random

import bpy
import bmesh
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Euler, Vector


OUTPUT = Path(__file__).resolve().parent
NAME = "Tornado_Nivel_4"
RIBBON_COUNT = 32
ASSET_COLLECTIONS = ("MAIN_BODY", "WIND_RIBBONS", "CYAN_DETAILS", "PARTICLES_AND_DEBRIS", "ROOT")
PALETTE = {
    "Graphite": "293443",
    "Slate": "3B4E61",
    "Steel": "51697E",
    "Silver": "9AADBF",
    "Ice": "BCDCE9",
    "Cyan": "48BCD9",
    "Debris": "586877",
}
PROFILE = ((-1.0, 0.0), (-0.72, -0.78), (0.37, -1.0),
           (1.0, -0.08), (0.62, 0.79), (-0.38, 1.0))


def linear_srgb(channel):
    value = int(channel, 16) / 255
    return value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4


def material(name, hex_color, roughness=0.57):
    color = tuple(linear_srgb(hex_color[i:i + 2]) for i in (0, 2, 4)) + (1.0,)
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = color
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = color
    shader.inputs["Roughness"].default_value = roughness
    return mat


def collection(scene, name):
    col = bpy.data.collections.new(name)
    scene.collection.children.link(col)
    return col


def mesh_object(name, col, vertices, faces):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.validate()
    mesh.update()

    editable = bmesh.new()
    editable.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(editable, faces=list(editable.faces))
    assert all(edge.is_manifold for edge in editable.edges), name
    assert editable.calc_volume(signed=True) > 0, name
    editable.to_mesh(mesh)
    editable.free()

    obj = bpy.data.objects.new(name, mesh)
    col.objects.link(obj)
    return obj


def make_ribbon(index, z, radius, band_width, depth, tilt, major_axis, start, sweep, drift, center, col, base, trim):
    """Sweep a beveled, flattened cross section along an open elliptical arc."""
    segments = min(32, 16 + round(radius * 3.0))
    rotation = Euler(tilt, "XYZ").to_matrix()
    vertices = []
    faces = []
    sides = len(PROFILE)

    for step in range(segments + 1):
        t = step / segments
        angle = start + sweep * t
        ripple = 1.0 + 0.035 * cos(3 * angle + index) + 0.025 * sin(2 * angle - index)
        radius_at = radius * ripple * (1 + 0.13 * (t - 0.5))
        radial = Vector((cos(angle), sin(angle) / major_axis, 0)).normalized()
        point = Vector((radius_at * cos(angle), radius_at * sin(angle) * major_axis,
                        drift * (t - 0.5) + depth * 0.55 * sin(2 * angle + index)))
        envelope = max(0.045, min(1.0, t / 0.13, (1 - t) / 0.18) ** 0.80)
        width = band_width * 0.5 * envelope * (1 + 0.19 * sin(2 * angle + index))
        half_depth = depth * 0.5 * envelope
        for radial_factor, height_factor in PROFILE:
            offset = radial * (radial_factor * width)
            offset.z = half_depth * height_factor
            local = rotation @ (point + offset)
            vertices.append(tuple(local))

    for step in range(segments):
        for side in range(sides):
            a = step * sides + side
            b = step * sides + (side + 1) % sides
            faces.append((a, b, b + sides, a + sides))
    faces.append(tuple(reversed(range(sides))))
    faces.append(tuple(segments * sides + i for i in range(sides)))

    obj = mesh_object(f"Ribbon_{index + 1:02d}_{col.name}", col, vertices, faces)
    obj.location = (*center, z)
    obj.data.materials.append(base)
    if trim:
        obj.data.materials.append(trim)
        for poly in obj.data.polygons[:-2]:
            if poly.index % sides in (4, 5) and 0.22 < (poly.index // sides) / segments < 0.73:
                poly.material_index = 1
    return obj


def tornado(scene):
    rng = Random(421)
    cols = {name: collection(scene, name) for name in ASSET_COLLECTIONS}
    colors = {name: material(name, value) for name, value in PALETTE.items()}
    root = bpy.data.objects.new("ROOT", None)
    cols["ROOT"].objects.link(root)
    root.empty_display_type = "PLAIN_AXES"
    root.empty_display_size = 0.58
    root.show_in_front = True
    asset = [root]
    cyan_layers = {9, 15, 21, 26, 30}

    for i in range(RIBBON_COUNT):
        u = i / (RIBBON_COUNT - 1)
        base_radius = 0.105 + 4.80 * u ** 0.86
        z = 0.12 + 10.9 * u ** 1.18
        center = (0.58 * sin(3.5 * u) + 0.87 * u * u, 0.37 * sin(5.3 * u))
        tilt = (radians(8 + 5.2 * sin(i * 0.71)), radians(5 * cos(i * 0.53)),
                radians((i * 31 + 14 * sin(i)) % 180))

        if i in cyan_layers:
            group, color, bevel = "CYAN_DETAILS", "Steel", "Cyan"
            scale, width = 1.12, 0.18
        elif i % 3 == 1 or i == RIBBON_COUNT - 1:
            group, color, bevel = "WIND_RIBBONS", ("Silver" if i % 3 else "Ice"), None
            scale, width = 1.10, 0.20
        else:
            group, color, bevel = "MAIN_BODY", ("Graphite", "Slate", "Steel")[i % 3], None
            scale, width = 0.89 + 0.035 * cos(i * 1.88), 0.36

        if i == RIBBON_COUNT - 1:
            scale, width = 1.17, 0.24
        radius = base_radius * scale * rng.uniform(0.97, 1.03)
        ribbon = make_ribbon(
            i, z, radius, radius * width, max(0.017, radius * (0.082 if group == "MAIN_BODY" else 0.061)),
            tilt, rng.uniform(0.75, 0.91), i * 2.39996323, rng.uniform(1.76, 1.94) * pi,
            min(radius * 0.29, 0.77), center, cols[group], colors[color], colors.get(bevel),
        )
        ribbon.parent = root
        asset.append(ribbon)

    lowest = min(obj.location.z + min(v.co.z for v in obj.data.vertices) for obj in asset[1:])
    for obj in asset[1:]:
        obj.location.z -= lowest

    for i in range(16):
        u = 0.18 + 0.73 * (i + rng.random()) / 16
        radius = (0.4 + 4.7 * u ** 0.87) * rng.uniform(1.04, 1.34)
        spin = i * 2.39996323
        size = rng.uniform(0.044, 0.128) * (0.45 + u)
        vertices = [(size, 0, 0), (0, size * 0.67, 0.15 * size), (-size * 0.8, 0, 0),
                    (0, -size, 0), (0.17 * size, 0, size * 1.04), (0, 0, -size * 0.46)]
        faces = [(4, j, (j + 1) % 4) for j in range(4)] + [(5, (j + 1) % 4, j) for j in range(4)]
        chunk = mesh_object(f"Debris_{i + 1:02d}", cols["PARTICLES_AND_DEBRIS"], vertices, faces)
        chunk.location = (0.36 + cos(spin) * radius, sin(spin) * radius * 0.88, 0.12 + 10.9 * u ** 1.18 - lowest)
        chunk.rotation_euler = (rng.uniform(-pi, pi), rng.uniform(-pi, pi), spin)
        chunk.data.materials.append(colors["Ice" if i % 5 == 0 else "Debris"])
        chunk.parent = root
        asset.append(chunk)
    return root, asset


def aimed_at(obj, target):
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()


def presentation(scene, asset):
    stage = collection(scene, "PRESENTATION")
    floor = mesh_object("Studio Floor", stage,
                        [(-200, -200, -0.022), (200, -200, -0.022), (200, 200, -0.022),
                         (-200, -200, -0.22), (200, -200, -0.22), (200, 200, -0.22),
                         (-200, 200, -0.022), (-200, 200, -0.22)],
                        [(0, 1, 2, 6), (3, 7, 5, 4), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 7, 6), (6, 7, 3, 0)])
    floor.data.materials.append(material("Neutral Backdrop", "B1B6BF", 0.86))
    camera_data = bpy.data.cameras.new("Presentation Camera")
    camera = bpy.data.objects.new("Presentation Camera", camera_data)
    stage.objects.link(camera)
    scene.camera = camera
    camera_data.lens = 54
    camera_data.clip_end = 500
    scene.render.resolution_x = 1240
    scene.render.resolution_y = 1440
    scene.render.resolution_percentage = 100

    bpy.context.view_layer.update()
    points = [obj.matrix_world @ vert.co for obj in asset if obj.type == "MESH" for vert in obj.data.vertices]
    z_top = max(v.z for v in points)
    target = Vector((0.51, 0, z_top * 0.53))
    direction = Vector((0.37, -1.0, 0.49)).normalized()
    distance = 22.0
    while distance < 80:
        camera.location = target + distance * direction
        aimed_at(camera, target)
        bpy.context.view_layer.update()
        if all(0.075 < p.x < 0.925 and 0.071 < p.y < 0.929
               for p in (world_to_camera_view(scene, camera, point) for point in points)):
            break
        distance += 0.7

    def area(name, loc, power, size, color):
        lamp = bpy.data.lights.new(name, "AREA")
        lamp.energy, lamp.shape, lamp.size, lamp.color = power, "DISK", size, color
        obj = bpy.data.objects.new(name, lamp)
        stage.objects.link(obj)
        obj.location = loc
        aimed_at(obj, target)

    area("Key", (-6, -8, 15), 1800, 10, (0.94, 0.97, 1.0))
    area("Fill", (8, -1, 9), 1000, 8, (0.82, 0.91, 1.0))
    area("Rim", (0, 7, 15), 2250, 8, (0.86, 0.95, 1.0))
    scene.world = bpy.data.worlds.new("Neutral Studio")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs[0].default_value = (0.48, 0.5, 0.55, 1.0)
    scene.world.node_tree.nodes["Background"].inputs[1].default_value = 0.68
    scene.view_settings.view_transform = "AgX"
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 24
    scene.cycles.use_denoising = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = f"//{NAME}.png"
    stage.hide_select = True

    # Open in material-colored solid mode without the stage obstructing modeling.
    for obj in stage.objects:
        obj.hide_set(True)
    for screen in bpy.data.screens:
        for area_ in screen.areas:
            if area_.type == "VIEW_3D":
                space = area_.spaces.active
                space.shading.color_type = "MATERIAL"
                space.region_3d.view_location = target
                space.region_3d.view_rotation = camera.rotation_euler.to_quaternion()
                space.region_3d.view_distance = distance * 0.76
                space.overlay.show_floor = False
                space.overlay.show_axis_x = False
                space.overlay.show_axis_y = False


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.name = NAME
    root, asset = tornado(scene)

    bpy.ops.object.select_all(action="DESELECT")
    for obj in asset[1:]:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = asset[1]
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    root.select_set(True)
    bpy.context.view_layer.objects.active = root

    assert sum(obj.name.startswith("Ribbon_") for obj in asset) == RIBBON_COUNT
    assert all(obj.parent == root for obj in asset[1:])
    for obj in asset[1:]:
        obj.data.calc_loop_triangles()
    ntri = sum(len(obj.data.loop_triangles) for obj in asset[1:])
    print(f"ASSET: {len(asset)-1} mesh objects, {ntri} triangles", flush=True)

    bpy.ops.export_scene.fbx(filepath=str(OUTPUT / f"{NAME}.fbx"), use_selection=True,
                             object_types={"EMPTY", "MESH"}, apply_unit_scale=True,
                             axis_forward="-Z", axis_up="Y", bake_anim=False, add_leaf_bones=False)
    bpy.ops.export_scene.gltf(filepath=str(OUTPUT / f"{NAME}.glb"), export_format="GLB",
                              use_selection=True, export_yup=True, export_animations=False)

    presentation(scene, asset)
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    bpy.context.view_layer.objects.active = root
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT / f"{NAME}.blend"), compress=True)
    bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    build()
