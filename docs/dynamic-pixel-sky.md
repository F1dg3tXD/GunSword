# Dynamic Pixel Sky Shader

**File:** `shaders/dynamic_pixel_sky.gdshader`  
**Type:** Sky shader  
**Renderer:** Compatible with Forward+, Mobile, and OpenGL Compatibility  
**Note:** Uses `EYEDIR` for direction (works on all renderers). `SCREEN_UV` is only available on Forward+.

A fully custom pixel art sky shader with day/night cycle, stars, moon, and volumetric clouds with sun-based shading. All parameters are exposed as uniforms and can be edited at runtime via `set_shader_parameter()`.

## Setup

1. Create a new `ShaderMaterial` and assign this shader.
2. Create a new `Sky` resource and assign the ShaderMaterial to its `sky_material`.
3. Assign the Sky to your `WorldEnvironment` node.
4. Animate the uniforms from GDScript to create the day/night cycle.

## How Pixelation Works

The shader uses the `EYEDIR` built-in (per-pixel sky direction) and quantizes it to a grid. This creates a pixel-art effect that's spherical rather than screen-space — the "pixels" are angular cells on the sky dome. The `pixel_count` uniform controls the grid density.

## Public API (GDScript)

```gdscript
# Get the sky material
var sky_mat = $WorldEnvironment.environment.sky.sky_material

# Animate time of day
sky_mat.set_shader_parameter("time_of_day", 0.5)  # noon

# Sync sun from DirectionalLight3D
var light = $DirectionalLight3D
sky_mat.set_shader_parameter("use_light_direction", true)
sky_mat.set_shader_parameter("sun_direction", -light.global_transform.basis.z)

# Change pixel resolution at runtime
sky_mat.set_shader_parameter("pixel_count", 64)
```

## Shader Uniforms

### Pixel Art

| Uniform | Type | Range | Default | Description |
|---|---|---|---|---|
| `pixel_count` | `int` | 16 - 4096 | 256 | Number of pixels along each axis. Lower = more pixelated. |

### Time of Day

| Uniform | Type | Range | Default | Description |
|---|---|---|---|---|
| `time_of_day` | `float` | 0.0 - 1.0 | 0.5 | 0.0 = midnight, 0.25 = sunrise, 0.5 = noon, 0.75 = sunset, 1.0 = midnight. Used when `use_light_direction` is false. |

### Light Source

| Uniform | Type | Default | Description |
|---|---|---|---|
| `use_light_direction` | `bool` | `true` | When true, sun position comes from `sun_direction` uniform (set from DirectionalLight3D). When false, computed from `time_of_day`. |
| `sun_direction` | `vec3` | `(0, -0.5, -1)` | Sun direction vector. Set from DirectionalLight3D rotation: `light.global_transform.basis.z` (negated). |

### Sun

| Uniform | Type | Range | Default | Description |
|---|---|---|---|---|
| `sun_size` | `float` | 0.001 - 0.1 | 0.025 | Angular size of the sun disk. |
| `sun_bloom` | `float` | 0.0 - 4.0 | 1.5 | Brightness of the sun glow. |
| `sun_bloom_size` | `float` | 0.0 - 0.5 | 0.15 | Size of the outer halo around the sun. |
| `sun_color` | `vec4` | - | `(1.0, 0.95, 0.8, 1.0)` | Color of the sun and its glow. |

### Moon

| Uniform | Type | Range | Default | Description |
|---|---|---|---|---|
| `show_moon` | `bool` | - | `true` | Show/hide the moon. |
| `moon_size` | `float` | 0.001 - 0.1 | 0.015 | Angular size of the moon disk. |
| `moon_bloom` | `float` | 0.0 - 2.0 | 0.3 | Moon glow intensity. |
| `moon_color` | `vec4` | - | `(0.85, 0.88, 1.0, 1.0)` | Color of the moon. |

### Sky Gradient

| Uniform | Type | Default | Description |
|---|---|---|---|
| `day_zenith` | `vec4` | `(0.05, 0.15, 0.55, 1.0)` | Sky color at zenith during day. |
| `day_sky` | `vec4` | `(0.25, 0.45, 0.85, 1.0)` | Mid-sky color during day. |
| `day_horizon` | `vec4` | `(0.55, 0.7, 1.0, 1.0)` | Horizon color during day. |
| `night_zenith` | `vec4` | `(0.0, 0.0, 0.02, 1.0)` | Sky color at zenith at night. |
| `night_sky` | `vec4` | `(0.0, 0.0, 0.08, 1.0)` | Mid-sky color at night. |
| `night_horizon` | `vec4` | `(0.0, 0.0, 0.12, 1.0)` | Horizon color at night. |
| `sunset_color` | `vec4` | `(1.0, 0.35, 0.05, 1.0)` | Sunset horizon glow color. |
| `sunrise_color` | `vec4` | `(1.0, 0.55, 0.15, 1.0)` | Sunrise horizon glow color. |

### Stars

| Uniform | Type | Range | Default | Description |
|---|---|---|---|---|
| `show_stars` | `bool` | - | `true` | Show/hide stars. |
| `star_layer_1_density` | `float` | 0.0 - 1.0 | 0.8 | Density of small dim background stars. |
| `star_layer_1_size` | `float` | 0.1 - 2.0 | 0.5 | Size of small background stars. |
| `star_layer_2_density` | `float` | 0.0 - 1.0 | 0.3 | Density of larger brighter stars. |
| `star_layer_2_size` | `float` | 0.5 - 4.0 | 1.5 | Size of larger brighter stars (includes cross-shaped glow). |
| `star_twinkle_speed` | `float` | 0.0 - 5.0 | 1.0 | Speed of the twinkle animation. |

### Clouds

| Uniform | Type | Range | Default | Description |
|---|---|---|---|---|
| `show_clouds` | `bool` | - | `true` | Show/hide clouds. |
| `cloud_coverage` | `float` | 0.0 - 1.0 | 0.5 | How much of the sky is covered by clouds. |
| `cloud_speed` | `float` | 0.0 - 0.5 | 0.02 | Horizontal scroll speed of clouds. |
| `cloud_scale` | `float` | 0.001 - 1.0 | 0.08 | Size of cloud formations. |
| `cloud_height` | `float` | 0.0 - 1.0 | 0.5 | Vertical threshold for cloud placement. |
| `cloud_detail` | `float` | 0.0 - 1.0 | 0.7 | Noise octaves for cloud detail (3–10 octaves). |
| `cloud_color_day` | `vec4` | - | `(1.0, 1.0, 1.0, 1.0)` | Cloud color during the day. |
| `cloud_color_sunset` | `vec4` | - | `(1.0, 0.65, 0.4, 1.0)` | Cloud color during sunset/sunrise. |
| `cloud_color_night` | `vec4` | - | `(0.08, 0.08, 0.12, 1.0)` | Cloud color at night. |
| `cloud_shadow` | `float` | 0.0 - 1.0 | 0.35 | Minimum brightness of cloud faces facing away from sun. |
| `cloud_bottom_shadow` | `float` | 0.0 - 1.0 | 0.25 | Shadow strength on the underside of clouds. |

## Day/Night Cycle Example

```gdscript
extends Node3D

@onready var env: WorldEnvironment = $WorldEnvironment
@onready var light: DirectionalLight3D = $DirectionalLight3D

var day_time: float = 0.5  # Start at noon
var day_speed: float = 0.01  # Full cycle in ~100 seconds

func _process(delta: float) -> void:
    day_time = fmod(day_time + delta * day_speed, 1.0)
    
    var sky_mat = env.environment.sky.sky_material
    sky_mat.set_shader_parameter("time_of_day", day_time)
    
    # Sync light rotation for cloud shadows
    light.rotation.x = -day_time * TAU + PI * 0.5
    sky_mat.set_shader_parameter("sun_direction", -light.global_transform.basis.z)
```

## How It Works

### Pixel Art Effect

The shader uses the `EYEDIR` built-in (per-pixel sky direction) and quantizes it to a grid. This creates a pixel-art effect that's spherical rather than screen-space — the "pixels" are angular cells on the sky dome. The `pixel_count` uniform controls the grid density (up to 4096 for high-quality clouds/stars).

### Day/Night Factor

The `raw_day` factor is computed from the sun's elevation using `smoothstep(-0.15, 0.25, sun_elevation)`. This creates smooth transitions:
- Below -0.15 elevation → full night
- Above 0.25 elevation → full day
- Between → smooth blend (sunset/sunrise)

### Sky Gradient

The gradient uses elevation-based blending with three control points (horizon, mid-sky, zenith) for both day and night. This eliminates harsh lines and creates natural color transitions at all elevations.

### Sun and Moon

Sun and moon are rendered as independent objects based on their direction vs `EYEDIR`. They're always visible when their direction is in view — no time-of-day masking. The sun has a disk, glow, and outer halo. The moon has a crescent effect and subtle glow.

### Stars

Stars use two layers: small dim background stars and larger brighter stars with cross-shaped glow. Star visibility fades smoothly as the sky brightens (no hard cutoff) and dims near the horizon (light pollution effect).

### Clouds

Clouds use high-quality FBM noise (3–10 octaves) with erosion for wispy edges. The noise is independent of the pixel quantization grid, so clouds look detailed even at low pixel counts. Cloud lighting is based on the sun's horizontal angle and cloud height (top-lit, bottom-shadowed).

### Horizon Glow

Sunset/sunrise glow is computed from the elevation angle using `exp(-abs(elevation) * 5.0)`, creating a smooth glow band at the horizon that fades naturally upward and downward.

## Tips

- Use `use_light_direction = true` with a DirectionalLight3D for accurate sun-based cloud shading.
- Animate `time_of_day` slowly for realistic day/night cycles (full cycle = 1.0 / speed seconds).
- Set `pixel_count` to 64-128 for a good pixel art look. Lower values (16-32) create very chunky pixels.
- The `cloud_shadow` value of 0.4 creates subtle shadowing. Increase to 0.7+ for dramatic dark undersides.
- For a stylized look, change the sky gradient colors to non-realistic values (purple day sky, green sunset, etc.).
