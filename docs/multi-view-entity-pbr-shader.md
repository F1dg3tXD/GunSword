# Multi-View Entity PBR Shader

**File:** `shaders/multi_view_entity_depth.gdshader`  
**Type:** Spatial shader  
**Renderer:** Compatible with Forward+, Mobile, and OpenGL Compatibility

A spatial shader for sprite-based entities that adds PBR (Physically Based Rendering) properties to AnimatedSprite3D nodes. Designed to work with the `MultiViewAnimatedSprite3D` layer system.

## Setup

1. Create a new `ShaderMaterial` and assign it to the entity's `material_override`.
2. Assign this shader to the ShaderMaterial.
3. On the `MultiViewAnimatedSprite3D`, assign SpriteFrames resources to `normal_frames`, `roughness_frames`, `depth_frames`, and/or `emission_frames`.

The system automatically syncs the current frame's texture to the shader on every animation frame change.

## Shader Uniforms

### Texture Maps

| Uniform | Type | Hint | Default | Description |
|---|---|---|---|---|
| `albedo_texture` | `sampler2D` | `source_color` | (required) | Base color texture. Auto-synced from `sprite_frames`. |
| `normal_texture` | `sampler2D` | `hint_normal` | Flat normal | Tangent-space normal map. |
| `roughness_texture` | `sampler2D` | `hint_default_white` | Fully rough | Grayscale roughness map. White = rough, black = smooth. |
| `depth_texture` | `sampler2D` | `hint_default_black` | No effect | Grayscale depth/parallax map. |
| `emission_texture` | `sampler2D` | `source_color, hint_default_black` | No emission | Color emission map. |

### PBR Controls

| Uniform | Type | Range | Default | Description |
|---|---|---|---|---|
| `normal_intensity` | `float` | 0.0 - 2.0 | 1.0 | Strength of the normal map. 0.0 = flat. |
| `roughness_value` | `float` | 0.0 - 1.0 | 0.5 | Base roughness when no roughness texture is used. |
| `roughness_mix` | `float` | 0.0 - 1.0 | 0.0 | How much the roughness texture influences the surface. 0.0 = use `roughness_value` only. |
| `depth_scale` | `float` | 0.0 - 1.0 | 0.0 | Strength of parallax UV offset. 0.0 = no parallax. |
| `emission_strength` | `float` | 0.0 - 16.0 | 0.0 | Emission brightness multiplier. > 0 spawns an OmniLight3D. |
| `modulate_color` | `vec4` | - | White | Tint multiplied into the albedo. |
| `emission_color` | `vec4` | - | White | Tint multiplied into the emission. |

## How It Works

### Rendering Pipeline

- **blend_mix** - Standard alpha blending.
- **depth_draw_always** - Writes depth for both opaque and transparent pixels (enables shadow casting).
- **depth_prepass_alpha** - Performs a depth pre-pass for transparent geometry (required for shadow maps).
- **cull_disabled** - Double-sided rendering (sprites visible from both sides).
- **ALPHA_SCISSOR_THRESHOLD = 0.1** - Discards pixels below 10% alpha to prevent shadow artifacts around sprite edges.

### Parallax Depth

When `depth_scale > 0`, the shader offsets UV coordinates based on the view direction and the depth texture. The parallax is computed first so all subsequent texture lookups (albedo, normal, roughness, emission) use the shifted UVs.

### Emission + Light Casting

The shader outputs `EMISSION = texture * emission_color * emission_strength`. This makes the sprite surface glow.

However, `EMISSION` alone does not illuminate nearby objects. When `emission_strength > 0`, the `MultiViewAnimatedSprite3D` script spawns a child `OmniLight3D` that matches the emission color and energy, casting real light onto surrounding geometry. The light's range is controlled by `emission_light_range` on the MultiViewAnimatedSprite3D node.

### Shadow Casting

Transparent sprites typically do not cast shadows. This shader enables shadow casting via:
1. `depth_draw_always` - ensures depth is written for transparent pixels.
2. `depth_prepass_alpha` - performs an opaque depth pre-pass so the shadow map renderer can see the sprite.
3. `ALPHA_SCISSOR_THRESHOLD` - prevents fully transparent pixels from casting shadow artifacts.

## Creating PBR SpriteFrames

Each PBR map must be a separate `SpriteFrames` resource with the **same animation names** as the base `sprite_frames`. The system matches by animation name and frame index.

### Example

If the base `sprite_frames` has animations `walk_front`, `walk_back`, `walk_left`, `walk_right`:

- **Normal frames**: Create a SpriteFrames with `walk_front`, `walk_back`, `walk_left`, `walk_right` containing normal map textures (typically purple/blue RGTC-compressed).
- **Roughness frames**: Create a SpriteFrames with the same animations containing grayscale textures (white = rough, black = smooth).
- **Emission frames**: Create a SpriteFrames with the same animations containing emission color textures (black = no emission).

If a PBR SpriteFrames is missing an animation that the base has, that PBR channel falls back to its default (flat normal, base roughness, no emission).

## Tips

- Set `roughness_mix` to `0.0` to use a uniform roughness value across the entire sprite (useful for stylized looks).
- Set `roughness_mix` to `1.0` for fully per-pixel roughness from the texture.
- Use `modulate_color` for runtime tinting (e.g. damage flash, team color).
- For pixel art, use nearest-neighbor filtering on all textures. The shader respects the node's `texture_filter` setting.
- Emission strength values above `1.0` create HDR glow when bloom is enabled.
