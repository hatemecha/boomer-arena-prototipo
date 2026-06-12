import bpy
import sys
from pathlib import Path

EXPORTS = [
    ("Pipes.blend", "pipes.glb"),
    ("Wires.blend", "wires.glb"),
    ("Transformer.blend", "transformer.glb"),
    ("Circuit Breaker.blend", "circuit_breaker.glb"),
    ("Pipe Valve.blend", "pipe_valve.glb"),
]

base_dir = Path(sys.argv[-1])


def export_blend(blend_name: str, glb_name: str) -> None:
    blend_path = base_dir / blend_name
    glb_path = base_dir / glb_name
    if not blend_path.exists():
        raise FileNotFoundError(f"Missing source file: {blend_path}")

    bpy.ops.wm.open_mainfile(filepath=str(blend_path))
    bpy.ops.export_scene.gltf(
        filepath=str(glb_path),
        export_format="GLB",
        use_selection=False,
        export_apply=True,
        export_materials="EXPORT",
        export_image_format="AUTO",
    )
    print(f"Exported {blend_name} -> {glb_name}")


for blend_name, glb_name in EXPORTS:
    export_blend(blend_name, glb_name)
