# FrustumCamera3D

**File:** `player/frustrum_camera_3d.gd`  
**Extends:** `Camera3D`  
**Annotation:** `@tool` (works in editor)

A performance-optimizing camera that hides `GeometryInstance3D` nodes outside its view frustum. Objects are shown/hidden based on AABB vs frustum plane intersection tests. Objects inside the camera's position are always visible.

## Setup

1. Add a `Camera3D` node to your scene.
2. Attach the `frustrum_camera_3d.gd` script to it.
3. Configure the exported properties in the inspector.

## Public API

```gdscript
# Force a re-scan of all cullable nodes in the scene tree.
# Call this after adding/removing significant geometry.
camera.refresh_cullables()
```

## Exported Properties

| Property | Type | Default | Description |
|---|---|---|---|
| `update_interval` | `float` | `0.1` | Seconds between cull checks. Lower = more responsive, higher = cheaper. |
| `margin` | `float` | `1.0` | AABB expansion in world units. Prevents pop-in at frustum edges. |
| `enabled` | `bool` | `true` | Toggle culling on/off at runtime. |

## How It Works

### Cullable Collection

On `_ready()`, the camera recursively walks the scene tree and collects all `GeometryInstance3D` nodes (meshes, particles, etc.) into an internal list. Call `refresh_cullables()` if the scene changes significantly after startup.

### Frustum Test (per tick)

1. Get the camera's 6 frustum planes via `get_frustum()`.
2. For each cullable node:
   a. Get its global AABB via `get_global_aabb()`.
   b. Expand the AABB by `margin` to prevent pop-in at edges.
   c. If the camera position is inside the AABB, show the object (camera is inside its bounds).
   d. Otherwise, test the AABB against all 6 frustum planes. If the AABB is fully outside any plane, hide it. Otherwise, show it.

### AABB-Plane Test

The test finds the corner of the AABB most aligned with the plane normal ("positive vertex"). If this corner is behind the plane, the entire AABB is outside the frustum.

### Edge Cases

- Nodes with empty AABBs (degenerate geometry) are skipped.
- Nodes that don't have `get_global_aabb()` are skipped (safety guard for non-standard types).
- Invalid/freed nodes are skipped.

## Performance Guidelines

| Scenario | Recommended `update_interval` |
|---|---|
| Fast-paced action | `0.05` - `0.1` |
| Exploration/adventure | `0.1` - `0.2` |
| Cutscenes/dialogue | `0.2` - `0.5` |

- Increase `margin` for fast camera movement to prevent objects popping in at screen edges.
- For large scenes with thousands of objects, consider combining with Godot's built-in `VisibleOnScreenNotifier3D` for two-tier culling.
- Call `refresh_cullables()` after level loads, scene transitions, or spawning large numbers of objects.

## Tips

- This is a `@tool` script — it works in the editor for preview purposes.
- The culling is additive to Godot's built-in visibility. An object hidden by frustum culling is simply `visible = false`.
- Objects hidden by this system still process `_process()` calls. For objects that need to stop processing when hidden, combine with visibility checks in your scripts.
- The system does not cull `GPUParticles3D` or `MultiMeshInstance3D` by default (they inherit from `GeometryInstance3D` and will be included).
