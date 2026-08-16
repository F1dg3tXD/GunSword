# Occlusion Window

Self-contained reveal-window system. A component mounted on the **camera** and/or on the
**character** punches a **soft-edged circular window** through anything drawn *in front*
of the player — walls, roofs, buildings, props — so the character stays visible while the
occlusion still reads correctly.

Two components ship in this addon, and it now bundles its own receiver shaders (no
external lighting addon required):

- **`OcclusionWindow2D`** (Node2D) — for 2D cameras/characters. The cut uses the
  y-sort depth line (screen-space, per fragment).
- **`OcclusionWindow3D`** (Node3D) — for 3D cameras/characters. The cut is
  camera-relative, based on view depth (distance from the camera plane), and the
  window radius is projected perspective-correctly so it frames the same world area
  around the character at any camera distance.

Both components and both receiver shaders work on the **Forward+** renderer and the
**OpenGL Compatibility** renderer.

---

## How it works

The window is punched by the receiver shader itself. Two screen-space global slots
(`occlusion_window_a_*`, `occlusion_window_b_*`) hold the active windows' center, radius,
depth line and fade; each frame the component writes its slot into those globals via
`RenderingServer.global_shader_parameter_set`. The receiver shaders fade the material's
alpha out inside a slot's window when the per-material opt-in
(`occlusion_window_occlude`) is on.

Because the cut is **per fragment in screen space**, it applies to sprites, plain nodes,
and `TileMapLayer` cells (2D) or any mesh the receiver material is used on (3D). Each
slot reveals a single `target`: empty targets fall back to the first node in the
`"player"` group, then to the component's parent (handy when mounted on the character
itself).

### 2D cutting rule (y-sort convention — larger Y is drawn in front)

	cut = receiver opted in (occlusion_window_occlude) AND receiver_depth > target_depth

The receiver's depth line is its origin in canvas space (`(MODEL_MATRIX * vec4(0,0,0,1)).y`),
and the component writes the target's `global_position.y`. The window is centered on the
target's anchor and its radius grows from zero at the depth line to full
`fade_distance` world pixels below it, so occluders just in front of the character barely
thin while deeper ones open fully — the reveal eases in and out instead of popping. The
player's own sprite sits exactly on the depth line and is never cut.

### 3D cutting rule (view depth = positive distance from the camera plane along the
camera's forward axis)

	cut = receiver opted in (occlusion_window_occlude) AND receiver_view_depth < target_view_depth

The receiver fragment's view depth is `-VIEW.z`; the component writes the target's view
depth. The window is centered on the target's projected anchor and its radius grows from
zero at the target's depth to full `fade_distance` world units **closer to the camera**,
so occluders just in front of the character barely thin while closer ones open fully. The
player's own body sits exactly on the depth line and is never cut.

## Setup (2D)

1. **Enable the plugin** in *Project → Project Settings → Plugins* (`Occlusion Window`).
2. **Create an occluder material**: a `ShaderMaterial` using
   `addons/occlusion_window/shaders/occlusion_window_2D.gdshader`, assigned to the
   occluder (sprite, `TileMapLayer` material override, prop).
3. **Opt in**: set the material's `occlusion_window_occlude` shader parameter to
   **true** on every layer/node that should be see-through in front of the player
   (walls, roofs, buildings, props). Base/floor layers and the player's own material
   stay off and are never cut.
   - For a `TileMapLayer`: assign the shader material to the layer (or its tileset
	 material) and set `occlusion_window_occlude = true`.
4. **Add the components**:
   - Camera mount: add an `OcclusionWindow2D` node as a child of your `Camera2D`
	 (`window_slot = A (camera)`).
   - Character mount: add an `OcclusionWindow2D` node as a child of the character
	 (`window_slot = B (character)`).
   Either mount alone works; both together merge into one reveal.
5. **Enable y-sorting** on the occluding layers (`y_sort_enabled` on the
   TileMapLayer / map root, or on the occluder node) so they can actually draw over the
   player.

## Setup (3D)

1. **Enable the plugin** as above.
2. **Create an occluder material**: a `ShaderMaterial` using
   `addons/occlusion_window/shaders/occlusion_window_3D.gdshader`, assigned to the
   occluder mesh. It renders the material's albedo texture and blends the window open.
3. **Opt in**: set `occlusion_window_occlude` to **true** on the occluders that should
   be see-through in front of the player (walls, pillars, props). Floor/base materials
   and the player's own stay off and are never cut.
4. **Add the components**:
   - Camera mount: add an `OcclusionWindow3D` node as a child of your `Camera3D`
	 (or its rig/pivot, so it follows the camera) with `window_slot = A (camera)`.
   - Character mount: add an `OcclusionWindow3D` node as a child of the 3D character
	 (`window_slot = B (character)`).
   Either mount alone works; both together merge into one reveal.

Run the scene and walk the player behind a wall/building: the occluder opens a circular
window with a vignette edge around the character, and closes it again as they pass.

### Automatic windowing (3D)

Instead of opting materials in one by one, set **`auto_window_geometry = true`** on an
`OcclusionWindow3D` (e.g. the one mounted on the player). It then treats **any** 3D
geometry between the target and the camera as something to look through: every few
frames it converts every opaque `StandardMaterial3D` / `ORMMaterial3D` mesh in the scene
to the receiver shader (copying its albedo texture and tint, opting it in), so walls,
pillars and props window automatically with zero setup. It never touches:

- **other 3D sprites** — `Sprite3D` / `AnimatedSprite3D` nodes (billboards, characters)
  are never converted, so they keep hiding the player normally,
- the **target's own subtree** (the player's sprite, UI, ...),
- **custom-shader materials** (anything that's already a `ShaderMaterial`),
- anything in the **`occlusion_window_exclude` group** — the escape hatch for floors or
  specific props you don't want windowed.

The receiver shader only cuts **roughly-vertical** surfaces by default (world-space
`abs(normal.y) < 0.5`), so the floor and roof tops stay solid instead of getting a hole
in front of the player. Set the material's `occlusion_window_vertical_only` to **false**
for the literal "any geometry" behaviour. The scan runs again every
`auto_scan_interval` seconds (default 0.5) so late-spawned geometry gets picked up.

## Component properties

### OcclusionWindow2D

| Property            | Default   | Meaning                                                            |
| ------------------- | --------- | ------------------------------------------------------------------ |
| `window_slot`       | A (camera)| Which global slot this component drives (A camera / B character).  |
| `target`            | (none)    | Character to reveal (Node2D). Empty falls back to group `"player"`,|
|                     |           | then to the component's parent.                                    |
| `window_radius`     | 70.0      | Window radius in world pixels (the fully-transparent core).        |
| `vignette_softness` | 0.35      | Fraction of the radius used for the soft edge (0 = hard, 1 = full).|
| `fade_distance`     | 40.0      | World px past the depth line before the window is fully open.      |
| `target_anchor`     | (0,-40)   | Point on the target the window follows (local to it).              |

### OcclusionWindow3D

| Property              | Default    | Meaning                                                         |
| --------------------- | ---------- | --------------------------------------------------------------- |
| `window_slot`         | A (camera) | Which global slot this component drives (A camera / B character).|
| `target`              | (none)     | Character to reveal (Node3D). Empty falls back to group `"player"`,|
|                       |            | then to the component's parent.                                 |
| `window_radius`       | 1.5        | Window radius in world units (metres, the transparent core).    |
| `vignette_softness`   | 0.35       | Fraction of the radius used for the soft edge (0 = hard, 1 = full).|
| `fade_distance`       | 3.0        | World units of view depth closer to the camera before fully open. |
| `target_anchor`       | (0,1,0)    | Point on the target the window follows (local to it).           |
| `auto_window_geometry`| false      | Auto-convert every StandardMaterial3D/ORMMaterial3D mesh in the |
|                       |            | scene to a receiver, so any geometry in front of the target is  |
|                       |            | looked through (see above).                                     |
| `auto_scan_interval`  | 0.5        | Seconds between auto-apply re-scans (catches late-spawned props).|

Tuning tips:

- **Bigger character** → raise `window_radius` so the whole body is revealed.
- **Softer reveal** → raise `vignette_softness` and/or `fade_distance`.
- **Reveal more of the body (2D)** → lower `target_anchor`'s Y (e.g. `(0, -70)`).
- **Reveal more of the body (3D)** → raise `target_anchor`'s Y (e.g. `(0, 1.5, 0)`).

## Multiple characters

Each slot reveals a single `target`. For multiple playable characters, either add one
component per character (a slot each) and point each `target` at its character, or
re-parent one component's `target` when the active character changes.

## Supported occluders

- 2D: `Sprite2D`, `AnimatedSprite2D`, `CanvasTexture` sprites (statues, trees, props),
  `TileMapLayer` cells and any canvas item using the 2D receiver material.
- 3D: any mesh whose material uses the 3D receiver shader and draws in front of the
  character (walls, pillars, props).

Limitations:

- Only materials using the addon's receiver shaders are cut; plain/unlit materials and
  UI are never affected.
- 2D: the depth line is each receiver's **transform origin Y**. For a sprite occluder
  whose origin isn't at its base, the cut line sits at its origin — keep occluder
  origins near their feet, or set the sprite's `y_sort_origin` and mirror it in the
  shader.
- The two slots are global: if several windows of the same slot exist in one scene they
  overwrite each other. Use one component per slot per scene.

## Renderer notes

- The receiver shaders use only standard built-ins (`SCREEN_UV`, `VIEW`, `MODEL_MATRIX`,
  `TEXTURE`, `INV_VIEW_MATRIX`, `global uniform`), all of which are supported by both the
  Forward+ and the OpenGL Compatibility renderers.
- 3D receiver material uniforms: `occlusion_window_occlude` (opt-in),
  `albedo_texture` + `albedo_color` (the auto-apply pass copies these from the original
  material so converted walls look identical), and `occlusion_window_vertical_only`
  (cuts only roughly-vertical surfaces; off = any surface between the target and camera).
- The window uniforms live in `occlusion_window_common.gdshaderinc`, shared by both
  receiver shaders. The feature is inert (guarded by the opt-in uniform and zero radius)
  when unused.
- 2D: the reveal is just an alpha cut in the occluder, so anything drawn behind the
  object at that spot shows through the window too — this matches the classic 2D "see the
  hero behind the building" look.
- 3D: the receiver material is alpha-blended (`blend_mix`) with `depth_draw_opaque`, so
  pixels inside the window don't write depth and reveal what's behind, while the rest of
  the occluder behaves normally. Blended materials don't receive shadows by default.

## Files

- `occlusion_window_2D.gd` — the 2D component (class `OcclusionWindow2D`, Node2D).
- `occlusion_window_3D.gd` — the 3D component (class `OcclusionWindow3D`, Node3D).
- `shaders/occlusion_window_2D.gdshader` — 2D receiver shader (canvas_item).
- `shaders/occlusion_window_3D.gdshader` — 3D receiver shader (spatial).
- `shaders/occlusion_window_common.gdshaderinc` — shared window-cut math + globals.
- `occlusion_window_plugin.gd` + `plugin.cfg` — editor plugin that registers both node
  types.
- `icon.svg` — node icon.
