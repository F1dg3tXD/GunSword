# EntityStatusBar

**File:** `entities/entity_status_bar.gd`  
**Scene:** `entities/entity_status_bar.tscn`  
**Extends:** `Node3D`

A modular health/status bar that renders above any entity (NPCs, enemies, breakable objects) using a SubViewport projected onto a 3D Sprite3D. The status bar never reaches back into the entity — all updates are pushed by the entity.

## Setup

1. Instance the `entity_status_bar.tscn` scene as a child of your entity.
2. Position it above the entity (typically `Vector3(0, 2, 0)` or similar).
3. Optionally assign status icon textures in the inspector.
4. From your entity script, call the public API methods whenever health or status changes.

## Public API

### Health

```gdscript
# Set the entity's current and max health.
# The bar becomes visible when current < max.
status_bar.set_health(75.0, 100.0)

# Get the current health percentage (0.0 to 1.0).
var pct = status_bar.get_health_percentage()
```

### Status Effects

```gdscript
# Apply a status effect (shows the icon).
status_bar.apply_status("stun")
status_bar.apply_status("burn")

# Clear the current status effect (hides the icon).
status_bar.clear_status()

# Register a custom effect with an icon at runtime.
status_bar.register_status_icon("frozen", frozen_texture)
status_bar.apply_status("frozen")
```

## Visibility Logic

| Health | Status Effect | Bar Visible? | Icon Visible? |
|---|---|---|---|
| 100% | None | No | No |
| 100% | Active | Yes | Yes |
| < 100% | None | Yes | No |
| < 100% | Active | Yes | Yes |

The entire `Status` Control node is hidden when health is at 100% and no status effect is active.

## Built-in Status Effects

| Effect Name | Export Property | Description |
|---|---|---|
| `"stun"` | `status_icon_stun` | Stun icon |
| `"burn"` | `status_icon_burn` | Burn icon |

Any number of additional effects can be registered at runtime via `register_status_icon()`.

## Example: NPC Integration

```gdscript
extends CharacterBody3D

@onready var status_bar: Node3D = $EntityStatusBar

var health: float = 100.0
var max_health: float = 100.0

func take_damage(amount: float) -> void:
    health = clamp(health - amount, 0.0, max_health)
    status_bar.set_health(health, max_health)

func apply_burn(duration: float) -> void:
    status_bar.apply_status("burn")
    await get_tree().create_timer(duration).timeout
    status_bar.clear_status()

func _ready() -> void:
    status_bar.set_health(health, max_health)
```

## Example: Breakable Object

```gdscript
extends StaticBody3D

@onready var status_bar: Node3D = $EntityStatusBar

var health: float = 50.0
var max_health: float = 50.0

func _ready() -> void:
    status_bar.set_health(health, max_health)

func hit() -> void:
    health -= 10.0
    status_bar.set_health(health, max_health)
    if health <= 0.0:
        queue_free()
```

## Scene Structure

```
EntityStatusBar (Node3D)          <- Script attached here
  SubViewport (SubViewport)       <- Transparent background
    Status (Control)              <- Shown/hidden by the script
      VBoxContainer
        statusIcon (TextureRect)  <- Status effect icon
        HealthBar (ProgressBar)   <- Health display
  Sprite3D                        <- Displays the SubViewport texture in 3D
```

## Tips

- The SubViewport is 128x128 with transparent background and HDR 2D enabled.
- The Sprite3D has `cast_shadow = 0` (disabled) so the health bar doesn't cast shadows.
- The ProgressBar uses a custom Theme with green fill and red background with rounded corners.
- For dynamic scaling, adjust the Sprite3D's `scale` or `pixel_size`.
- The status bar is decoupled from the entity — any node type can use it by calling the public methods.
