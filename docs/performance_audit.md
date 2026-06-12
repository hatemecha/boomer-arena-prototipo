# Performance Audit PSX

Fecha: 2026-06-12

## Cambios aplicados

- `Default` queda como perfil visual base: 640x360 interno, shader PSX completo, glow y VFX actuales.
- `Low` usa 640x360, cap efectivo de 60 FPS, shader PSX rapido, glow off, disco a 20 Hz, pickups a 20 Hz y limites menores de decals/trazadores.
- `Ultra Low` usa 426x240, cap efectivo de 30 FPS, shader PSX rapido, glow off, disco a 10 Hz, pickups a 10 Hz sin luz dinamica y VFX minimos.
- Se desactivo `meshes/create_shadow_meshes` en 39 imports de modelos, porque el proyecto ya desactiva sombras runtime.
- No se redujeron texturas ni modelos del perfil `Default`.

## Assets pesados detectados

| Peso | Asset | Nota |
| ---: | --- | --- |
| 11.26 MiB | `assets/music/funkytown_lipps_inc.ogg` | Candidato a version mas corta o compresion menor bitrate para builds chicas. |
| 4.84 MiB | `assets/music/ulterior_motives_1985_aop_mix.ogg` | Revisar loop/corte si el build apunta a PC muy baja o web. |
| 3.45 MiB | `assets/models/pickups/low_poly_medkit.glb` | Alto para pickup; candidato a malla/texturas simplificadas. |
| 3.16 MiB | `assets/models/props/music_stereo/90s_style_low_poly_stereo.glb` | Prop pesado; mantener unico o crear LOD/manual low variant. |
| 1.96 MiB | `assets/models/pickups/low_poly_medkit_5.png` | Textura grande para look PSX; downscale opcional a 256/512 si no pierde lectura. |
| 1.12 MiB | `assets/music/covers/funkytown_lipps_inc.jpg` | Cover UI; candidato a 512 o 256 px. |
| 0.84 MiB | `assets/music/covers/ulterior_motives.jpg` | Cover UI; candidato a 512 o 256 px. |
| 1.09 MiB | `assets/models/weapons/low_poly_msmc.glb` | Aceptable si es arma principal; revisar si incluye texturas sobredimensionadas. |
| 0.75 MiB | `assets/models/player/among_us_animado.glb` | Aceptable para prototipo; revisar animaciones/materiales si hay varios jugadores. |

## Carpetas candidatas a excluir en export release

Actualmente no existe `export_presets.cfg`, asi que no se aplico cambio de export.

Cuando se cree, conviene excluir:

- `.godot/`
- `docs/`
- `FOXTEX COMPLETE/`
- `addons/debug_draw_3d/libs/*editor*`
- `addons/debug_draw_3d/libs/*template_debug*`
- assets de ejemplo, herramientas y librerias debug no usadas en runtime

## Candidatos para una pasada futura

- Crear versiones PSX manuales de `low_poly_medkit.glb` y `90s_style_low_poly_stereo.glb`.
- Reducir covers y texturas de props a 256/512 px manteniendo nearest filtering.
- Revisar si `FOXTEX COMPLETE/` esta solo como fuente de trabajo; si es asi, moverlo fuera del proyecto o excluirlo de export.
- Agregar preset de export release con filtros de exclusion y compresion definida.
