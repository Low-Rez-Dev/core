# Arm Control & Z-Depth System Mechanics

## Overview
This document explains the detailed mechanics of the dual-arm control system and the 2.5D Z-depth implementation in our modular game architecture, updated with current understanding and implementation details.

## Dual-Arm Control System

### Core Concept
Each arm is controlled independently, allowing for complex tactical gameplay where players can perform different actions simultaneously with each hand. The system uses semantic movement recording and contextual stance-based controls.

### Input Mapping

#### Mouse & Keyboard
- **Left Mouse Button** → Left arm activation (red arm)
- **Right Mouse Button** → Right arm activation (blue arm)
- **Mouse Position** → Target for active arm(s)
- **Mouse Wheel** → Universal grip strength control (always active)
- **Tab + Mouse Wheel** → Camera zoom override
- **A/D Keys** → Movement along current cardinal axis
- **Q/E Keys** → Cardinal orientation rotation
- **Mouse Chording** → Hold one button, press other to lock first arm position

#### Controller
- **Left Trigger** → Left arm activation (analog pressure)
- **Right Trigger** → Right arm activation (analog pressure)
- **Left Stick** → Left arm control (when left trigger held)
- **Right Stick** → Right arm control (when right trigger held)
- **Left Stick** → Character movement (when triggers released)
- **Right Stick** → Focus direction (when triggers released)
- **L2/R2 Shoulder Buttons** → Stance cycling and arm locking
- **D-pad Up/Down** → Z-axis depth lane movement
- **D-pad Left/Right** → Cardinal orientation rotation

### Arm Mechanics

#### IK (Inverse Kinematics) System
Each arm consists of two segments:
- **Upper Arm** (shoulder to elbow)
- **Lower Arm** (elbow to hand)

The system calculates natural elbow positioning using:
1. **Law of Cosines** to determine joint angles
2. **Reach limiting** to prevent impossible arm extensions
3. **Facing-dependent elbow bending** for natural movement
4. **Consistent elbow direction** - both arms bend the same way based on character facing

```gdscript
# Simplified IK calculation with consistent elbow bending
var distance = target_pos.distance_to(shoulder_pos)
if distance > arm_reach:
    target_pos = shoulder_pos + (target_pos - shoulder_pos).normalized() * arm_reach

var elbow_direction = 1.0 if facing_right else -1.0  # Both arms use same direction
var angle_a = acos((upper_arm² + distance² - lower_arm²) / (2 * upper_arm * distance))
var elbow_pos = shoulder_pos + Vector2(cos(angle + elbow_direction * angle_a), sin(angle + elbow_direction * angle_a)) * upper_arm_length
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

#### Grip Strength System
- **Universal Control** → Mouse wheel always controls grip strength
- **Automatic Decay** → Grip loosens over time, requires maintenance
- **Weight-Based Training** → Heavier objects build strength but cause more fatigue
- **Cross-Stance Integration** → Works in all stances (combat, climbing, crafting)
- **Disarming Resistance** → Stronger grip prevents weapon loss
- **Climbing Safety** → Direct control over rope/ladder grip

### Body Mechanics

#### Proportional Body System
All body parts scale proportionally based on adjustable parameters:
- **Body Scale** - overall size multiplier
- **Torso Width/Height** - body proportions
- **Arm Lengths** - reach and proportions
- **Head/Neck Size** - visual scaling
- **Variability Zones** - designated areas for muscle/fat expansion

#### Facing System
Character facing changes based on actual movement, not mouse position:
- **Movement-Based Facing** - only actual velocity changes facing direction
- **Arms maintain anatomical consistency** - RED=left, BLUE=right always
- **Visual triangle indicator** - shows facing direction
- **Anti-jitter system** - prevents rapid facing changes from mouse movement

#### Rest Positions
When arms are inactive, they return to natural poses:
- **Hip Level** - relaxed arm positioning
- **Stance-Dependent** - different rest positions for each stance
- **Proportional to body** - scales with character size
- **Facing Aware** - positions adjust when character turns

## Z-Depth 2.5D System

### Coordinate System
The game uses a **dual-axis movement system** with discrete Z-positioning:
- **Movement Axis** - Free analog movement along current cardinal facing
- **Depth Axis** - Discrete 1-meter lane stepping perpendicular to movement
- **Y-Axis** - Vertical (ground level with terrain following)

### Movement Philosophy

#### Dual-Axis Design
**Current Cardinal Facing Determines Axes:**
- **Facing East/West**: X-axis = Movement (free), Z-axis = Depth (discrete lanes)
- **Facing North/South**: Z-axis = Movement (free), X-axis = Depth (discrete lanes)

**Control Mapping:**
- **A/D Keys**: Smooth analog movement along Movement Axis
- **D-pad Up/Down**: Step between discrete lanes on Depth Axis
- **Q/E Rotation**: Swaps which world axis serves as Movement vs Depth

**Tactical Applications:**
- **Formation Combat**: Smooth positioning within ranks (Movement Axis)
- **Lane Changes**: Discrete stepping between battle lines (Depth Axis)
- **Building Navigation**: Fluid room movement, discrete floor changes

### Visual Design Philosophy

#### Direct 2D Procedural Rendering
- **Pure 2D canvas rendering** using direct polygon drawing
- **Ant Farm Depth Lanes** - each lane as separate CanvasLayer
- **Procedural entities** built from direct draw commands
- **No SubViewport dependencies** - eliminates IK tuning issues

#### Depth Visual Effects
- **Layer-based depth sorting** - manual Z-order by depth lane + Y position
- **Progressive effects per layer** - blur, transparency, desaturation by distance
- **Direct canvas effects** - immediate visual feedback for IK adjustments
- **Focus cone rendering** - sharp detail within attention area using direct drawing

### Technical Implementation

#### Component Architecture
```
Main (Node2D)
├── DepthLane_-2 (CanvasLayer) - background lanes
├── DepthLane_-1 (CanvasLayer) - midground  
├── DepthLane_0 (CanvasLayer) - active player lane
├── DepthLane_1 (CanvasLayer) - foreground
├── DepthLane_2 (CanvasLayer) - far foreground
├── Character2D (Node2D - main character)
│   ├── BodyController (IK calculations + morphology)
│   ├── InputHandler (Mouse/Controller/AI input)
│   ├── Movement2DController (2D movement with depth lane switching)
│   └── DirectRenderer (Canvas draw commands)
├── Camera2D (Simple 2D camera with zoom/pan)
└── DebugOverlay (Direct debug line drawing)
```

#### Movement System
**2D Positioning** (Movement2DController):
- Handles dual-axis movement with simulated 3D depth
- Manages discrete depth lane switching between CanvasLayers
- Provides smooth movement along current facing axis
- Triggers layer visibility and sorting updates

**Direct Canvas Rendering** (DirectRenderer):
- Pure 2D polygon drawing using CanvasItem draw commands
- IK arm calculations drive direct line/circle drawing
- Immediate visual feedback for real-time IK tuning
- No intermediate textures or viewport scaling issues

#### Grid System
- **Simulated 3D positioning** using 2D coordinates with depth lane indexing
- **CanvasLayer depth separation** - each lane renders at different Z-levels
- **Manual sorting within lanes** - entities sorted by Y position for proper overlap
- **Visual grid references** drawn directly to debug overlay

### IK Development Integration

#### Direct Visual Feedback
- **Real-time IK tuning** - immediate visual response to parameter changes
- **Debug line drawing** - shoulder positions, reach circles, joint angles drawn directly
- **Pixel-perfect mouse mapping** - 1:1 screen coordinates to character space
- **No viewport scaling** - consistent coordinate system eliminates tuning issues

#### Performance Benefits
- **Direct to framebuffer** - no 3D pipeline or SubViewport overhead
- **Simple draw calls** - polygon primitives drawn directly to canvas
- **Immediate mode rendering** - draw exactly what's needed when needed
- **Cache efficient** - linear memory access patterns for optimal performance

### Terrain Integration

#### Terrain Design Rules
- **Smooth Within Blocks** - gentle slopes, no sudden height changes within 1-meter grid blocks
- **Sharp Changes at Boundaries** - dramatic height differences occur at exact lane boundaries
- **Ant Farm Consistency** - each depth lane shows clean terrain cross-section

#### Special Terrain Types
**Stair Blocks:**
- **Camera-Dependent Behavior**:
  - Front view: Platform mechanics (jump up/down, Down+Jump to drop through)
  - Side view: Normal terrain surfaces for leg IK
- **Default Position**: Bottom step when entering stair block
- **Same Lane Navigation**: No depth changes needed when viewed from front

**Moveable Ladders:**
- **Cardinal Placement Only**: North, East, South, West orientations
- **Dual Behavior**: Platform mode (front view) vs ramp mode (side view)
- **Cross-Pattern Climbing**: Right hand up triggers left leg up automatically

### Stance Integration

#### Equipment-Dependent Stances
- **Tool Requirements**: Stances only available with appropriate equipment
- **Targeting Categories**: Stance determines valid interaction targets
- **Collision Layers**: Different stances collide with different object types
- **Rest Positions**: Each stance has unique arm positioning

#### Built-in Actions
- **Throwing Mechanics**: Built-in trajectory patterns with skill-based prediction arcs
- **Climbing Techniques**: Auto-grasp system with cross-pattern movement
- **Combat Patterns**: Stance-specific muscle memory mapping

### Focus/Attention System
- **Focus cone** emanates from character head
- **Active arm targeting** - focus follows active arm for precise control
- **Sharp vision within cone** - detailed interaction within attention area
- **Peripheral blur** - reduced detail outside focus area
- **Dead reckoning memory** - static memory of areas outside current vision

## Advanced Integration

### Muscle Memory System
- **Semantic Recording**: [retract arm][away from][enemy] → [extend arm][towards][enemy]
- **Grasp State Tracking**: [parallel/perpendicular to forearm], [swing from perpendicular to parallel]
- **Stance-Specific Mapping**: Same gesture means different actions in different stances
- **Contextual Adaptation**: Techniques work across similar weapon types

### Climbing Mechanics
- **Auto-Grasp Safety**: Arms maintain grip by default, release only when activated
- **Leg Assistance**: Passive leg kinematics provide stability and reduce arm fatigue
- **Cross-Pattern Movement**: Natural diagonal climbing coordination
- **Dual-Rail Sliding**: Grip both ladder sides for controlled descent

### Combat Applications
- **Formation Fighting**: Smooth positioning within phalanx ranks
- **Weapon Techniques**: Built-in throwing with prediction arcs
- **Shield Wall Tactics**: Lock shield arm while maneuvering spear
- **Z-Layer Positioning**: Tactical depth changes for advantage

## Debug & Development

### Visual Debug Tools
- **Coordinate Flow Tracking**: Complete input-to-output coordinate chain
- **IK Visualization**: Arm positioning and elbow calculation display
- **Stance Indicators**: Current stance and available transitions
- **Grip Strength Display**: Real-time grip level and decay visualization

### Emergency Systems
- **Comprehensive Diagnostics**: Full system state analysis
- **Emergency Reset**: Large-scale character reset for visibility
- **Coordinate Debugging**: Real-time position and axis tracking

This system creates unique tactical gameplay where spatial positioning, timing, coordination, and grip management all matter, while maintaining the charm of 2D character art in a 3D world with authentic climbing and combat mechanics.