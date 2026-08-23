# MultiViewAnimatedSprite3D

**File:** `entities/multi_view_animated_sprite_3d.gd`  
**Extends:** `AnimatedSprite3D`  
**Class:** `MultiViewAnimatedSprite3D`

A billboarded 3D sprite that automatically switches directional animations based on the camera's relative position. Supports Doom-style layer compositing and PBR shading via shader integration.

## Quick Start

1. Add a `MultiViewAnimatedSprite3D` node to your scene.
2. Create a `SpriteFrames` resource with animations named using directional suffixes (e.g. `walk_front`, `walk_back`, `walk_left`, `walk_right`).
3. Assign it to the `sprite_frames` property.
4. Call `play3d("walk")` from your entity script. The system automatically picks the correct direction.

## Animation Naming Convention

Animations are grouped by a **base name** + **direction suffix**. The system scans all animations at startup and groups them automatically.

### Default Suffixes (4-way)

| Direction | Suffix | Example |
|---|---|---|
| Front | `_front` | `idle_front` |
| Back | `_back` | `idle_back` |
| Left | `_left` | `idle_left` |
| Right | `_right` | `idle_right` |

### Optional Suffixes (8-way)

| Direction | Suffix | Example |
|---|---|---|
| Front-Left | `_front_left` | `idle_front_left` |
| Front-Right | `_front_right` | `idle_front_right` |
| Back-Left | `_back_left` | `idle_back_left` |
| Back-Right | `_back_right` | `idle_back_right` |

### Vertical Suffixes

| Direction | Suffix | Example |
|---|---|---|
| Top | `_top` | `idle_top` |
| Bottom | `_bottom` | `idle_bottom` |

All suffixes are customizable via exported properties.

## Public API

### Playback

```gdscript
# Play a directional animation. Automatically picks the correct direction.
sprite.play3d("walk")

# Play at custom speed.
sprite.play3d("walk", 1.5)

# Play from end in reverse.
sprite.play3d("walk", 1.0, true)

# Play with a random start frame.
sprite.play3d("idle", 1.0, false, true)

# Stop playback.
sprite.stop3d()
```

### Layer System

Layers are `SpriteFrames` resources stacked back-to-front. Layer 0 uses the node's own `sprite_frames`. Layers 1+ automatically create child `Sprite3D` nodes that sync to the current animation/frame.

```gdscript
# Get the number of layers.
var count = sprite.get_layer_count()

# Add a new layer.
sprite.add_layer(my_sprite_frames)

# Remove a layer.
sprite.remove_layer(2)

# Enable/disable a layer.
sprite.enable_layer(1)
sprite.disable_layer(1)

# Check if a layer is enabled.
var active = sprite.is_layer_enabled(1)

# Set layer visibility directly.
sprite.set_layer_visible(1, false)

# Tint a layer.
sprite.set_layer_modulate(1, Color.RED)

# Replace a layer's SpriteFrames.
sprite.set_layer(1, new_sprite_frames)
```

### PBR Shader Integration

When a `ShaderMaterial` is assigned to `material_override`, the system automatically syncs PBR textures from SpriteFrames resources. Each PBR map's SpriteFrames must share the same animation names as the base `sprite_frames`.

```gdscript
# Assign PBR maps (SpriteFrames with matching animation names).
sprite.normal_frames = normal_map_frames
sprite.roughness_frames = roughness_map_frames
sprite.depth_frames = depth_map_frames
sprite.emission_frames = emission_map_frames
```

On every frame change, the system sets the following shader parameters:
- `albedo_texture` - current frame from `sprite_frames`
- `normal_texture` - current frame from `normal_frames`
- `roughness_texture` - current frame from `roughness_frames`
- `depth_texture` - current frame from `depth_frames`
- `emission_texture` - current frame from `emission_frames`

If `emission_strength > 0` on the shader, a child `OmniLight3D` is spawned and synced to cast real light onto the scene.

## Exported Properties

### Layers

| Property | Type | Default | Description |
|---|---|---|---|
| `sprite_layer_frames` | `Array[SpriteFrames]` | `[]` | SpriteFrames resources stacked back-to-front |
| `layer_visible` | `Array[bool]` | `[]` | Per-layer visibility toggle |
| `layer_modulate` | `Array[Color]` | `[]` | Per-layer tint color |
| `normal_frames` | `SpriteFrames` | `null` | Normal map SpriteFrames |
| `roughness_frames` | `SpriteFrames` | `null` | Roughness map SpriteFrames |
| `depth_frames` | `SpriteFrames` | `null` | Depth/parallax map SpriteFrames |
| `emission_frames` | `SpriteFrames` | `null` | Emission map SpriteFrames |
| `emission_light_range` | `float` | `5.0` | Range of the emission OmniLight3D |

### Direction

| Property | Type | Default | Description |
|---|---|---|---|
| `forward_dir` | `Vector3` | `(0, 0, -1)` | Local forward direction |
| `up_dir` | `Vector3` | `(0, 1, 0)` | Local up axis |
| `elevation_threshold` | `float` | `60.0` | Angle (degrees) for top/bottom switch |

### Directional Animations

| Property | Type | Default | Description |
|---|---|---|---|
| `use_8_way` | `bool` | `false` | Enable 8-directional (diagonal) animations |
| `forward_suffix` | `String` | `"_front"` | Forward direction suffix |
| `back_suffix` | `String` | `"_back"` | Backward direction suffix |
| `left_suffix` | `String` | `"_left"` | Left direction suffix |
| `right_suffix` | `String` | `"_right"` | Right direction suffix |
| `front_left_suffix` | `String` | `"_front_left"` | Front-left diagonal suffix |
| `front_right_suffix` | `String` | `"_front_right"` | Front-right diagonal suffix |
| `back_left_suffix` | `String` | `"_back_left"` | Back-left diagonal suffix |
| `back_right_suffix` | `String` | `"_back_right"` | Back-right diagonal suffix |
| `top_suffix` | `String` | `"_top"` | Top-down suffix |
| `bottom_suffix` | `String` | `"_bottom"` | Bottom-up suffix |
| `animations` | `Array[String]` | `[]` | Auto-populated discovered base animation names |

## How Direction Switching Works

Every frame while a directional animation is playing, the system:

1. Computes the camera's position relative to the sprite in local space.
2. Determines the horizontal angle to choose left/right/back/front.
3. Checks the vertical elevation angle against `elevation_threshold` to choose top/bottom.
4. If the suffix changed, switches to the new directional animation while preserving playback position (normalized frame progress).
5. Falls back to `front` if the exact directional animation doesn't exist.

## Fallback Order

If the exact directional animation is missing, the system falls back in this order:
`front` -> `back` -> `left` -> `right` -> `front_left` -> `front_right` -> `back_left` -> `back_right` -> `top` -> `bottom`

## Tips

- Use `play3d("idle")` for continuous directional animations. The system handles switching automatically.
- For non-directional animations (cutscenes, UI), use `super.play()` directly.
- Layer order matters: index 0 is behind index 1. Use `layer_modulate` for tinting equipment pieces.
- Set `elevation_threshold` lower (e.g. `30.0`) for tighter top/bottom detection, or higher (e.g. `80.0`) for wider horizontal bands.
