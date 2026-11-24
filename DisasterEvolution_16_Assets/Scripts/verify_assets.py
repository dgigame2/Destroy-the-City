"""Reopen the master and reimport all FBX and GLB files in Blender."""
import bpy
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
manifest = json.loads((root/"manifest.json").read_text(encoding="utf-8"))
assert len(manifest) == 16
bpy.ops.wm.open_mainfile(filepath=str(root/"DisasterEvolution_16_Assets.blend"))
project = bpy.data.collections["DISASTEREVOLUTION"]
assert {c.name for c in project.children} == {"TORNADO_FORMS","Q_SKILLS"}
for item in manifest:
    collection = bpy.data.collections[item["name"]]
    pivot = collection.objects[item["name"]+"_ROOT"]
    assert pivot.type == "EMPTY" and abs(pivot.location.z)<1e-5
    assert len([obj for obj in pivot.children_recursive if obj.type=="MESH"]) == item["meshes"]
    for phase in item["phases"]:
        assert any(obj.name.startswith(phase) for obj in pivot.children)
    for obj in pivot.children_recursive:
        if obj.type=="MESH":
            assert max(map(abs,obj.rotation_euler))<1e-5
            assert max(abs(v-1.0) for v in obj.scale)<1e-5
            assert obj.data.materials and obj.data.color_attributes
print("MASTER VALIDATED: 16 editable collections",flush=True)

for extension in ("fbx","glb"):
    for item in manifest:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        file = root/extension.upper()/f"{item['name']}.{extension}"
        if extension=="fbx":
            bpy.ops.import_scene.fbx(filepath=str(file),colors_type="SRGB")
        else:
            bpy.ops.import_scene.gltf(filepath=str(file))
        bpy.context.view_layer.update()
        pivot = bpy.context.scene.objects[item["name"]+"_ROOT"]
        assert pivot.type=="EMPTY" and pivot.matrix_world.translation.length<1e-5
        meshes = [obj for obj in pivot.children_recursive if obj.type=="MESH"]
        assert len(meshes)==item["meshes"], (file,len(meshes),item["meshes"])
        assert all(not obj.animation_data and obj.data.color_attributes for obj in meshes), file
        triangles=0
        for obj in meshes:
            obj.data.calc_loop_triangles()
            triangles+=len(obj.data.loop_triangles)
        assert triangles==item["triangles"], (file,triangles,item["triangles"])
        for phase in item["phases"]:
            assert any(obj.name.startswith(phase) for obj in pivot.children), (file,phase)
        if item["name"]=="Twin_Cyclones":
            child_names = {obj.name for obj in pivot.children_recursive if obj.type=="EMPTY"}
            assert {"CYCLONE_A","CYCLONE_B"}<=child_names
        main=next(child for child in pivot.children if child.name.startswith("MAIN"))
        points=[obj.matrix_world@vertex.co for obj in main.children_recursive
                if obj.type=="MESH" for vertex in obj.data.vertices]
        low = [min(p[i] for p in points) for i in range(3)]
        high = [max(p[i] for p in points) for i in range(3)]
        assert abs(low[2])<.002, (file,low)
        dims = [b-a for a,b in zip(low,high)]
        assert all(abs(a-b)<.004 for a,b in zip(dims,item["dimensions"])), (file,dims)
        print(f"VERIFY {file.name}: {len(meshes)} meshes, {triangles} triangles, pivot and colors OK",flush=True)

print("VERIFIED: 1 master and 32 exports.",flush=True)

