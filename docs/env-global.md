# EnvGlobal

**File:** `scripts/env_global.gd`  
**Autoload:** `EnvGlobal`

A global singleton that configures lighting, sprites, and scatter density across the entire scene tree. Runs on startup and provides runtime configuration for foliage density.

## Auto-Configuration (On Startup)

### Lights

All `Light3D` nodes in the scene tree receive:
- `shadow_bias = 0.01`
- `shadow_blur = 0.0`

### Sprites

All `SpriteBase3D` nodes in the scene tree receive:
- `alpha_cut = ALPHA_CUT_DISCARD` (binary alpha, no blending)
- `texture_filter = 0` (nearest-neighbor filtering, for pixel art)

## Scatter Density Control

The foliage density system caps `Scatter` node amounts at a maximum value. Original amounts are preserved so density can be raised back up after being lowered.

### Setting Density

From the Video Options menu, or from any script:

```gdscript
# Set maximum scatter amount across all Scatter nodes.
EnvGlobal.configure_scatter(300)   # High
EnvGlobal.configure_scatter(250)   # Normal
EnvGlobal.configure_scatter(150)   # Reduced
EnvGlobal.configure_scatter(100)   # Minimal
EnvGlobal.configure_scatter(50)    # Potato
```

### How It Works

1. On first call, each `Scatter` node's original `amount` is recorded (keyed by instance ID).
2. `configure_scatter(max_amount)` sets `scatter.amount = min(original, max_amount)` for every `Scatter` node in the scene tree.
3. If a Scatter node's original amount is already below the max, it is not changed.
4. If the max is raised back up, original amounts are restored.

### Integration with Options Menu

The Video Options menu's "Foiliage Density" setting calls `EnvGlobal.configure_scatter()` when changed:

| Setting | Max Amount |
|---|---|
| High | 1800 |
| Normal | 1000 |
| Reduced | 500 |
| Minimal | 100 |
| Potato | 50 |

## Public API

```gdscript
# Set the maximum scatter amount for all Scatter nodes in the scene tree.
EnvGlobal.configure_scatter(max_amount: int)
```

## Tips

- Call `configure_scatter()` after loading new levels to apply the current density setting.
- The system stores original amounts per instance ID, so it handles dynamic object creation correctly.
- The density setting persists across scene changes (stored in the VideoSettings config section).
