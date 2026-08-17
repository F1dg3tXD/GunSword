# Cylinder Cut

A world-space cylinder cut-through system for Godot 4. Punches a configurable 3D cylinder between two anchor points through all intersecting geometry, with automatic material conversion and multiple edge styles.

## Features

- **World-space cylinder cut** — invisible cutting volume between two Node3D anchors
- **Automatic material conversion** — scans the scene tree and converts opaque StandardMaterial3D / ORMMaterial3D to the receiver shader
- **GridMap support** — automatically applies to GridMap mesh libraries
- **Configurable edge** — soft gradient, hard cut, or custom texture (dissolve, ring patterns)
- **Works with Forward+ and Compatibility renderers**

## Setup

1. Enable the plugin in **Project > Project Settings > Plugins**
2. Add a `CylinderCutNode` as a child of your player CharacterBody3D
3. Point `player_point` and `cam_point` at your two anchor Node3D nodes
4. Any opaque mesh in the scene tree will automatically cut through

## Usage

### Player Scene Setup

```
PlayerTopDown (CharacterBody3D)
  ├── sprite (AnimatedSprite3D)
  │   └── player_point (Node3D)
  ├── CameraRig (Node3D)
  │   └── SpringArm3D
  │       └── Camera3D
  │           └── cam_point (Node3D)
  └── CylinderCut (CylinderCutNode)  ← add this
```

### Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `player_point` | Node3D | — | Start point of the cylinder |
| `cam_point` | Node3D | — | End point of the cylinder |
| `radius` | float | 2.0 | Cylinder radius in world units |
| `softness` | float | 0.3 | Edge blend width (0 = hard, 1 = soft) |
| `edge_texture` | Texture2D | — | Optional 1D texture mapping distance → alpha |
| `auto_window_geometry` | bool | true | Auto-scan and convert materials |
| `auto_scan_interval` | float | 0.5 | How often to re-scan for late-added geometry |

### Excluding Nodes

Add nodes to the `cylinder_cut_exclude` group to skip them during auto-scan:

```gdscript
node.add_to_group("cylinder_cut_exclude")
```

### Manual Material Setup

For full control, manually assign the receiver shader to your materials:

```
Shader: res://addons/cylinder_cut/shaders/cylinder_cut_receiver.gdshader
```

Set these shader parameters:
- `cylinder_cut_occlude` → `true`
- `albedo_texture` → your texture
- `albedo_color` → your tint color

### Edge Styles

The default edge is a smooth `softness`-controlled gradient. Drop in one of the example edge shader includes for different looks:

```
shaders/examples/edge_soft.gdshaderinc     — smooth gradient
shaders/examples/edge_hard.gdshaderinc     — sharp boolean cut
shaders/examples/edge_dissolve.gdshaderinc — organic noise dissolve
shaders/examples/edge_ring.gdshaderinc     — concentric sine rings
```

To use, replace the edge function in the receiver shader:

```glsl
#include "res://addons/cylinder_cut/shaders/examples/edge_hard.gdshaderinc"
```

## Architecture

```
addons/cylinder_cut/
├── plugin.cfg                          # Plugin registration
├── icon.svg                            # Editor icon
├── cylinder_cut_plugin.gd              # EditorPlugin (registers custom type)
├── cylinder_cut_node.gd                # Main Node3D (auto-apply, global updates)
├── shaders/
│   ├── cylinder_cut_common.gdshaderinc # Shared cylinder math + global uniforms
│   ├── cylinder_cut_receiver.gdshader  # Spatial receiver (cutoff + edge)
│   └── examples/
│       ├── edge_soft.gdshaderinc
│       ├── edge_hard.gdshaderinc
│       ├── edge_dissolve.gdshaderinc
│       └── edge_ring.gdshaderinc
```

### Global Shader Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `cylinder_cut_a` | vec3 | World position of anchor A (player) |
| `cylinder_cut_b` | vec3 | World position of anchor B (camera) |
| `cylinder_cut_radius` | float | Cut radius in metres |
| `cylinder_cut_softness` | float | Edge blend width fraction |
| `cylinder_cut_edge_tex_on` | float | 1.0 if edge_texture is set |

These are written by `CylinderCutNode._process()` every frame.
