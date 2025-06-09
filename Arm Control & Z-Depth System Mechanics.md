# Arm Control & Z-Depth System Mechanics

## Overview
This document explains the detailed mechanics of the dual-arm control system and the 2.5D Z-depth implementation in our modular game architecture.

## Dual-Arm Control System

### Core Concept
Each arm is controlled independently, allowing for complex tactical gameplay where players can perform different actions simultaneously with each hand.

### Input Mapping

#### Mouse & Keyboard
- **Left Mouse Button** → Left arm activation
- **Right Mouse Button** → Right arm activation  
- **Mouse Position** → Target for active arm(s)
- **Q Key** → Move forward in Z-depth
- **E Key** → Move backward in Z-depth
- **WASD** → XY movement on current Z-layer

#### Controller
- **Left Trigger** → Left arm activation
- **Right Trigger** → Right arm activation
- **Left Stick** → Left arm control (when left trigger held)
- **Right Stick** → Right arm control (when right trigger held)
- **Left Stick** → Character movement (when triggers released)
- **Right Stick** → Focus direction (when triggers released)

### Arm Mechanics

#### IK (Inverse Kinematics) System
Each arm consists of two segments:
- **Upper Arm** (shoulder to elbow)
- **Lower Arm** (elbow to hand)

The system calculates natural elbow positioning using:
1. **Law of Cosines** to determine joint angles
2. **Reach limiting** to prevent impossible arm extensions
3. **Facing-dependent elbow bending** for natural movement

```gdscript
# Simplified IK calculation
var distance = target_pos.distance_to(shoulder_pos)
if distance > arm_reach:
    target_pos = shoulder_pos + (target_pos - shoulder_pos).normalized() * arm_reach

var angle_a = acos((upper_arm² + distance² - lower_arm²) / (2 * upper_arm * distance))
var elbow_pos = shoulder_pos + Vector2(cos(angle), sin(angle)) * upper_arm_length
```

#### Chording System
Allows tactical "locking" of arms for complex maneuvers:

**Mouse Chording:**
1. Hold left mouse → left arm tracks cursor
2. While holding left, press right mouse → left arm locks at current position
3. Right arm now tracks cursor independently
4. Press left mouse again → unlocks left arm
5. Release both → both arms return to rest

**Controller Chording:**
1. Hold shoulder button → locks respective arm at current position
2. Can move and look around while arm stays locked
3. Release shoulder → arm unlocks
4. Double-tap shoulders → start/stop recording muscle memory

### Body Mechanics

#### Proportional Body System
All body parts scale proportionally based on adjustable parameters:
- **Body Scale** - overall size multiplier
- **Torso Width/Height** - body proportions
- **Arm Lengths** - reach and proportions
- **Head/Neck Size** - visual scaling

#### Facing System
Character facing changes based on focus direction:
- **Focus cone** emanates from head center
- **Arms and body** mirror when facing direction changes
- **Locked arm positions** rotate to prevent breaking when turning

#### Rest Positions
When arms are inactive, they return to natural poses:
- **Hip Level** - relaxed arm positioning
- **Proportional to body** - scales with character size
- **Facing Aware** - positions adjust when character turns

## Z-Depth 2.5D System

### Coordinate System
The game uses a **discrete 3D grid** with 1-meter increments:
- **X-Axis** - Left/Right movement
- **Z-Axis** - Forward/Back through depth layers  
- **Y-Axis** - Vertical (currently locked to ground level)

### Visual Design Philosophy

#### Paper Cutout Aesthetic
- **2D character sprites** in 3D space
- **Always face camera** - sprites rotate to maintain front-facing view
- **3D environment** - terrain, water, structures provide spatial context
- **Depth cueing** through visual effects

#### Depth Visual Effects
- **Progressive blur** - background layers become more blurred
- **Transparency** - foreground objects gain transparency
- **Color shifting** - distant objects become more desaturated

### Technical Implementation

#### Component Architecture
```
GameWorld3D (Node3D)
├── DebugMarkers (Visual reference grid)
├── Player3D (Node3D - 3D positioning)
│   ├── ModularPlayerController (CharacterBody2D - 2D visual)
│   │   ├── BodyController (2D body mechanics)
│   │   └── InputHandler (Input processing)
│   └── Movement3DController (3D movement logic)
└── Camera3D (3D camera system)
```

#### Movement System
**3D Positioning** (Movement3DController):
- Handles discrete Z-layer movement
- Snaps to 1-meter grid positions
- Manages XY movement in 3D space
- Prevents rapid Z-movement with cooldowns

**2D Rendering** (ModularPlayerController):
- Purely visual representation
- IK arm calculations in 2D space
- Focus cone and body drawing
- No actual physics movement

#### Grid System
- **Discrete layers** at integer Z coordinates
- **Visual grid** shows each Z-layer with different colors
- **Landmark cubes** provide spatial reference points
- **Coordinate labels** show exact grid positions

### Input Flow

#### Complete Input Chain
1. **Input Detection** - InputHandler captures raw input
2. **3D Movement** - Movement3DController processes WASD + Q/E
3. **Arm Targeting** - InputHandler calculates 2D arm targets
4. **Body Update** - BodyController processes arm IK and facing
5. **Visual Rendering** - ModularPlayerController draws everything

#### Focus System
- **Mouse Mode** - Focus follows cursor when arms inactive
- **Controller Mode** - Right stick controls focus when triggers released
- **3D Integration** - Focus direction influences character facing
- **Visual Feedback** - Focus cone shows attention direction

### Tactical Implications

#### Combat Applications
- **Archery** - Lock bow arm, draw with arrow arm
- **Shield Fighting** - Lock shield position, attack with weapon arm
- **Dual Wielding** - Independent weapon control
- **Throwing** - Wind up with one arm while defending with other

#### Environmental Navigation
- **Z-Layer Tactics** - Hide behind/in front of objects
- **Focus Management** - Look around while maintaining arm positions
- **Spatial Awareness** - Grid system creates clear positioning

#### Crafting Applications
- **Two-Handed Work** - Each hand performs different tasks
- **Tool Coordination** - Hold material with one hand, work with other
- **Precision Control** - Fine motor control for quality crafting

## Technical Considerations

### Performance
- **2D Rendering** - Character drawing is lightweight 2D
- **Discrete Movement** - No continuous collision detection needed
- **Component Isolation** - Systems can be optimized independently

### Scalability
- **Modular Design** - Easy to add new character types
- **Input Abstraction** - New input methods (AI, network) plug in easily
- **Visual Separation** - 2D rendering independent of 3D positioning

### Future Extensions
- **Multiple Z-Layers** - Characters on different depth levels
- **Camera Rotation** - 90-degree turns to show different cardinal views
- **Depth Interactions** - Objects that span multiple Z-layers
- **Layered Combat** - Attacks that can hit multiple depth levels

## Debug & Development

### Visual Debug Tools
- **Grid Lines** - Show Z-layer boundaries
- **Coordinate Labels** - Display exact positions
- **Landmark Cubes** - Reference points for navigation
- **Position Highlighting** - Visual feedback for movement

### Testing Commands
- **Page Up/Down** - Direct Z-layer movement (debug)
- **Ctrl + Arrows** - Direct grid movement (debug)
- **Console Output** - Movement and state feedback

This system creates a unique tactical gameplay experience where spatial positioning, timing, and coordination all matter, while maintaining the charm of 2D character art in a 3D world.