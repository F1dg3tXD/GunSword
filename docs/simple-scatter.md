# Simple Scatter

**Directory:** `addons/simple_scatter/`  
**Classes:** `Scatter` (scatter.gd), `ScatterShape` (scatter_shape.gd)

A tool-based scattering system for placing objects on surfaces. Supports Cylinder, Box, and Sphere shapes with uniform random distribution. Objects are raycast onto physics geometry to find their final position.

## Setup

1. Add a `Node3D` to your scene and attach `scatter.gd` (or add via the Scatter class).
2. Add a `CollisionShape3D` child with your desired shape (Cylinder, Box, or Sphere).
3. Assign PackedScene objects to the `objects` array.
4. Adjust `amount`, `randomScale`, and other properties in the inspector.

The scatter regenerates automatically whenever any property changes.

## Exported Properties

| Property | Type | Default | Description |
|---|---|---|---|
| `objects` | `Array[PackedScene]` | `[]` | Scenes to scatter (one is chosen randomly per placement). |
| `amount` | `int` | `10` | Number of objects to place. |
| `randomScale` | `float` (0.0-1.0) | `0.0` | Random scale variation. 0.0 = uniform, 1.0 = 0% to 100% scale. |
| `scatterSeed` | `int` | `0` | Random seed for reproducible layouts. |
| `use_all_normals` | `bool` | `false` | Allow placement on any surface normal (walls, ceilings). Default: floors only. |
| `random_rotation_delta` | `float` (0.0-TAU) | `0.0` | Random rotation around the surface normal (radians). |

## How It Works

1. For each object to place, a random position is generated within the CollisionShape3D's volume.
2. A ray is cast from that position upward (or downward) to find the nearest physics surface.
3. If `use_all_normals` is `false`, only surfaces facing upward accept objects (dot with UP >= 0.5).
4. The object is placed at the hit position with optional random scale and rotation.
5. Ray length is bounded by the shape's vertical half-extent, preventing placement outside the volume.

## Supported Shapes

| Shape | Distribution Method | Vertical Bound |
|---|---|---|
| `CylinderShape3D` | Uniform disk sampling | `height * 0.5` |
| `BoxShape3D` | Uniform volume sampling | `size.y * 0.5` |
| `SphereShape3D` | Uniform volume sampling | `radius` |

## ScatterShape Details

The `scatter_shape.gd` script attaches to the `CollisionShape3D` child and provides:

- `get_random_position() -> Vector3` - Returns a random world-space position within the shape.
- `get_vertical_half_extent() -> float` - Returns the shape's vertical extent for ray bounding.

All shapes generate uniform distributions (no clustering at center).

## Example Scene Structure

```
Scatter (Node3D) + scatter.gd
  CylinderShape3D + scatter_shape.gd    <- Volume to scatter within
  objectsContainer (Node3D)              <- Auto-created, holds spawned objects
```

## Tips

- Change `scatterSeed` to get different but reproducible layouts.
- Set `random_rotation_delta` to `PI` for full random rotation, or `TAU` for complete 360-degree freedom.
- Use `use_all_normals = true` for cave walls, ceilings, or any non-horizontal surface.
- The scatter regenerates in the editor when properties change (it's a `@tool` script).
- Combine with `EnvGlobal.configure_scatter()` for runtime foliage density control.
- Objects are placed under an `objectsContainer` child node for easy cleanup.
