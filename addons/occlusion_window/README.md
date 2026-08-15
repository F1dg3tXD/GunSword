# Occlusion Window

Reveal-window system for 2D games built on the `Lit` lighting addon. One component
mounted on the **2D camera** and/or on the **character** punches a **soft-edged
circular window** through anything drawn *in front* of the player — tile layers,
sprites, nodes, buildings — so the character stays visible while the y-sorted
occlusion still reads correctly.

Works on both the **Forward+** and the **OpenGL/Compatibility (web)** renderers.

---

## How it works

The window is punched by the Lit receiver shader itself. `lit_header.gdshaderinc`
declares two screen-space global slots (`lit_window_a_*`, `lit_window_b_*`) plus a
per-receiver opt-in (`lit_window_occlude`); `lit_fragment.gdshaderinc` fades the
receiver's alpha out in a circle when a slot is active. The `OcclusionWindow` component
is a tiny node that each frame writes its slot's center (the target's screen position),
radius, depth line and fade into the global uniforms via
`RenderingServer.global_shader_parameter_set`.

Because the cut is **per fragment in screen space**, it applies to sprites, plain
nodes, and `TileMapLayer` / `LitTileMapLayer` cells alike (a y-sorted tile layer
renders per-row child items, and each cell's y-sort depth travels with it through the
`v_item_depth` varying).

**Cutting rule** (y-sort convention — larger Y is drawn in front):

	cut = receiver opted in (lit_window_occlude) AND receiver_depth > target_depth

The window is centered on the target's anchor and its radius grows from zero at the
depth line to full `fade_distance` world pixels below it, so occluders just in front of
the character barely thin while deeper ones open fully — the reveal eases in and out
instead of popping.

## Setup

1. **Enable the plugins** in *Project → Project Settings → Plugins* (`Lit` and
   `Occlusion Window`). The occlusion addon depends on the Lit receiver pipeline.
2. **Mark the occluding materials**: for every layer/node that should be see-through in
   front of the player (walls, roofs, buildings, props), set the material's
   `lit_window_occlude` shader parameter to **true**. This is deliberate: base/floor
   layers and the player's own material stay off and are never cut.
   - For a `LitTileMapLayer`, add `shader_parameter/lit_window_occlude = true` to the
	 layer's material, or set it in code:
	 `$WallLayer.material.set_shader_parameter("lit_window_occlude", true)`.
   - For a `LitSprite2D` / sprite with a lit material, do the same on its material.
3. **Add the components**:
   - Camera mount: add an `OcclusionWindow` node as a child of your `Camera2D`
	 (`window_slot = A (camera)`).
   - Character mount: add an `OcclusionWindow` node as a child of the character
	 (`window_slot = B (character)`).
   Either mount alone works; both together merge into one reveal.
4. **Enable y-sorting** on the occluding layers (`y_sort_enabled` on the
   TileMapLayer / map root, or on the occluder node) so they can actually draw over the
   player.

Run the scene and walk the player behind a wall/building: the occluder opens a circular
window with a vignette edge around the character, and closes it again as they pass.

## Component properties

| Property            | Default   | Meaning                                                            |
| ------------------- | --------- | ------------------------------------------------------------------ |
| `window_slot`       | A (camera)| Which global slot this component drives (A camera / B character).  |
| `target`            | (none)    | Character to reveal. Empty falls back to group `"player"`, then    |
|                     |           | to the component's parent.                                         |
| `window_radius`     | 70.0      | Window radius in world pixels (the fully-transparent core).        |
| `vignette_softness` | 0.35      | Fraction of the radius used for the soft edge (0 = hard, 1 = full).|
| `fade_distance`     | 40.0      | World px past the depth line before the window is fully open.      |
| `target_anchor`     | (0,-40)   | Point on the target the window follows (local to it).              |

Tuning tips:

- **Bigger character** → raise `window_radius` so the whole body is revealed.
- **Softer reveal** → raise `vignette_softness` and/or `fade_distance`.
- **Reveal more of the body** → lower `target_anchor`'s Y (e.g. `(0, -70)`).

## Multiple characters

Each slot reveals a single `target`. For multiple playable characters, either add one
component per character (a slot each) and point each `target` at its character, or
re-parent one component's `target` when the active character changes.

## Supported occluders

- `TileMapLayer` / `LitTileMapLayer` cells (y-sorted layers; only cells drawn in front
  of the character are cut).
- `Sprite2D`, `AnimatedSprite2D`, `CanvasTexture` sprites (statues, trees, props) and
  any node with a Lit receiver material.

Limitations:

- Only **Lit receivers** are cut (materials using the lit receiver shaders). Plain,
  unlit layers and UI are never affected.
- The depth line is each receiver's **transform origin Y** (or the tile row's Y). For a
  sprite occluder whose origin isn't at its base, the cut line sits at its origin —
  keep occluder origins near their feet, or set the sprite's `y_sort_origin`.
- The two slots are global: if several windows of the same slot exist in one scene they
  overwrite each other. Use one component per slot per scene.

## Renderer notes

- The window uniforms live in the shared receiver include chain
  (`lit_receiver_common.gdshaderinc`), so they exist in **every** receiver variant —
  fast/ysort/cone/stoch and the OpenGL twins. No variant swapping is needed and the
  feature is inert (guarded by zero radius and the per-receiver opt-in) when unused.
- Since the reveal is just an alpha cut in the occluder, anything drawn behind the
  object at that spot (a wall, another prop) shows through the window too — this
  matches the classic 2D "see the hero behind the building" look.

## Files

- `occlusion_window.gd` — the component (class `OcclusionWindow`).
- `occlusion_window_plugin.gd` + `plugin.cfg` — editor plugin that registers the node
  type.
- `icon.svg` — node icon.
- Shader support lives in `addons/lit/shaders/receiver/include/`:
  `lit_header.gdshaderinc` (uniforms, `v_item_depth`) and `lit_fragment.gdshaderinc`
  (the punch).
