# 🎮 Implemented Game Features Documentation

## Overview
This document covers the core systems that have been implemented and debugged in the 2.5D tactical dual-arm control game. All systems are functional and follow specific design rules.

---

## 🎥 Cardinal Rail Camera System

### **Core Rules:**
- **Hard Rail Positioning**: Camera snaps to exact cardinal positions, no smooth following
- **No Free Camera**: Camera cannot rotate independently - locked to 4 cardinal directions
- **Movement Parallel Tracking**: Camera rail runs parallel to player movement axis

### **Functionality:**
- **4 Cardinal Positions**: East, North, West, South rails
- **Q/E Rotation**: Cycles through all 4 orientations (clockwise/counter-clockwise)
- **Rail Following**: Camera slides along rail as player moves, maintaining exact distance
- **Instant Positioning**: No lerp() or smooth transitions - immediate rail snapping

### **Camera-Movement Relationship:**
```
Player Facing → Camera Position → Camera Rail Direction
East         → North Rail     → E-W rail (follows E-W movement)
South        → East Rail      → N-S rail (follows N-S movement)  
West         → South Rail     → E-W rail (follows E-W movement)
North        → West Rail      → N-S rail (follows N-S movement)
```

### **Technical Implementation:**
- `update_rail_position()` forces exact positioning
- No `look_at()` micro-rotations - uses exact cardinal directions
- Immediate response to orientation changes

---

## 🦾 Dual-Arm IK Control System

### **Core Rules:**
- **Independent Arm Control**: Each arm controlled separately with mouse buttons
- **Anatomical Consistency**: RED=left arm, BLUE=right arm (always)
- **Cursor Accuracy**: Arms always point exactly toward cursor position
- **Natural Elbow Bending**: Elbows bend downward/outward in all facing directions

### **Mouse Control:**
- **Left Mouse Button**: Controls left arm (red)
- **Right Mouse Button**: Controls right arm (blue)
- **Mouse Chording**: Hold one button, press other to lock first arm position
- **Rest Positions**: Arms return to hip-based rest when inactive

### **IK Calculation Rules:**
- **Elbow Direction**: Based on facing direction, not individual arm
  - **Facing Right**: Both arms use `elbow_direction = 1.0` (bend downward)
  - **Facing Left**: Both arms use `elbow_direction = -1.0` (bend downward)
- **Reach Limiting**: Arms cannot extend beyond natural reach
- **Law of Cosines**: Accurate joint angle calculation for realistic movement

### **Coordinate System:**
- **Facing Right**: Standard coordinate system (mouse left = arms left)
- **Facing Left**: Mirrored coordinate system 
  - Mouse position and shoulder positions both mirrored
  - Result: arms still point accurately toward cursor

### **Arm Positioning Rules:**
```
Facing Direction → Left Shoulder → Right Shoulder → Mouse Tracking
Right           → (-12, -17)   → (12, -17)     → Direct
Left            → (-12, -17)   → (12, -17)     → Mirrored coordinates
```

---

## 🧭 Cardinal Movement System

### **Core Rules:**
- **Facing-Based Movement**: A/D moves along the direction character is facing
- **4 Cardinal Facings**: East, South, West, North (full 360° in 90° increments)
- **Axis-Relative Movement**: Movement always along current facing axis

### **Movement Directions:**
```
Facing → A Key (Backward) → D Key (Forward)
East   → West (-X)        → East (+X)
South  → North (+Z)       → South (-Z)  
West   → East (+X)        → West (-X)
North  → South (-Z)       → North (+Z)
```

### **Rotation System:**
- **Q Key**: Clockwise rotation (East→South→West→North→East)
- **E Key**: Counter-clockwise rotation (East→North→West→South→East)
- **Cooldown**: Prevents rapid rotation spam
- **Speed Control**: Shift for running (4.0 m/s) vs walking (1.5 m/s)

### **Movement Rules:**
- **Grid-Based**: 1-meter discrete coordinate system
- **Ground-Locked**: Y-axis always at 0 (no jumping yet)
- **Immediate Response**: No acceleration/deceleration curves
- **Camera Synchronization**: Movement orientation changes camera rail

---

## 🎭 Character Facing & Direction System

### **Core Rules:**
- **Movement-Based Facing**: Only actual movement changes facing direction
- **No Mouse-Based Facing**: Mouse position does not affect body facing
- **Triangle Indicator**: Yellow triangle shows facing direction
- **Consistent Arm Sides**: Arms never swap anatomical positions

### **Facing Logic:**
```
Movement Orientation → Velocity Check → Facing Direction
East (0)            → velocity.x > 0  → Right (forward)
South (1)           → velocity.z < 0  → Right (forward) 
West (2)            → velocity.x < 0  → Right (forward)
North (3)           → velocity.z > 0  → Right (forward)
```

### **Visual Indicators:**
- **Yellow Triangle**: Points left when facing left, right when facing right
- **Text Display**: "FACING: LEFT/RIGHT" in character texture
- **Arm Colors**: RED=left stays red, BLUE=right stays blue
- **Triangle Update**: Immediate visual update when facing changes

### **Anti-Jitter Rules:**
- **Facing Change Condition**: Only changes if different from current
- **No Rapid Toggling**: Movement-only determination prevents mouse jitter
- **Stable Rest Positions**: Arms don't swap when character turns

---

## 🎨 Entity2D5D Rendering System

### **Core Rules:**
- **2D Characters in 3D Space**: SubViewport renders 2D character to texture
- **Camera-Facing Sprites**: Characters always face current camera orientation
- **Consistent Scaling**: 1.5x scale = ~2 meter tall character
- **Performance Optimization**: Single texture per entity

### **Rendering Pipeline:**
1. **BodyController**: Calculates IK and body data
2. **CharacterDrawer**: Draws 2D character in SubViewport
3. **SubViewport**: Renders to texture at 60 FPS
4. **Sprite3D**: Displays texture in 3D world

### **Sprite Orientation Rules:**
```
Movement Orientation → Sprite Rotation → Camera View
East (0)            → 0° (North)     → Camera faces North
South (1)           → 90° (East)     → Camera faces East
West (2)            → 180° (South)   → Camera faces South  
North (3)           → 270° (West)    → Camera faces West
```

### **Scaling & Positioning:**
- **Scale**: Vector3(1.5, 1.5, 1.5) for human-sized character
- **Position**: Y=1.0 (character center at 1m height)
- **Ground Reference**: Character feet at Y=0

---

## 🎛️ Input System Architecture

### **Core Rules:**
- **Modular Design**: MouseKeyboard, Controller, and AI input handlers
- **Raw Input Detection**: Bypasses Godot action mapping for reliability
- **3D-to-2D Conversion**: Accurate mouse coordinate transformation
- **Input Abstraction**: Character systems work with any input type

### **MouseKeyboard Input:**
- **Mouse Buttons**: Direct `Input.is_mouse_button_pressed()` detection
- **Movement Keys**: Raw `Input.is_key_pressed()` for A/D movement
- **Rotation Keys**: Q/E for orientation changes
- **Camera Integration**: Uses camera projection for accurate 3D-to-2D conversion

### **Coordinate Conversion Rules:**
1. **Get mouse screen position**
2. **Project character 3D position to screen**
3. **Calculate relative mouse position** 
4. **Scale to character 2D space** (0.35 scale factor)
5. **Apply facing direction coordinate transformation**

### **Chording System:**
- **Lock Mechanism**: Hold one button, press other to lock first arm
- **Unlock**: Press locked button again to unlock
- **Release All**: Both buttons released = all locks cleared

---

## 🐛 Debug & Development Tools

### **Debug Commands:**
- **T Key**: Triangle and facing direction debug
- **F Key**: Manual facing toggle + texture refresh
- **C Key**: Comprehensive coordinate flow debug
- **M Key**: Mouse coordinate debug
- **R Key**: Force texture refresh

### **Debug Output:**
```
Coordinate Flow Debug Shows:
1. Raw mouse screen position
2. Processed mouse from input handler  
3. Character facing direction
4. Shoulder positions (left/right)
5. Calculated arm targets
6. Expected arm pointing directions
```

### **Emergency Recovery:**
- **Enter**: Full system diagnostics
- **Escape**: Emergency reset with large scale
- **Space**: Create debug marker at player position

---

## ⚙️ Technical Architecture

### **Component Hierarchy:**
```
Character2D5D (Entity2D5D base)
├── BodyController (IK calculations)
├── InputHandler (MouseKeyboardInput/ControllerInput)  
├── Movement3DController (3D movement logic)
├── SubViewport (2D rendering)
│   └── CharacterDrawer (2D drawing)
└── Camera25D (Rail camera system)
```

### **Data Flow:**
1. **Input** → InputHandler processes raw input
2. **Movement** → Movement3DController handles 3D positioning
3. **Body** → BodyController calculates IK and facing
4. **Render** → CharacterDrawer draws to SubViewport
5. **Display** → Sprite3D shows texture in 3D world

### **Performance Considerations:**
- **60 FPS Texture Updates**: SubViewport renders at consistent framerate
- **Discrete Movement**: No continuous collision detection needed
- **Component Isolation**: Systems can be optimized independently
- **Single Texture**: Each character uses one texture, not multiple sprites

---

## 🎯 Design Philosophy

### **Core Principles:**
1. **Precision Over Smoothness**: Exact positioning beats smooth transitions
2. **Tactical Control**: Each arm independently controlled for complex maneuvers
3. **Visual Clarity**: Clear indicators show state (facing, arm activity, positions)
4. **Consistent Behavior**: Same rules apply regardless of camera or facing direction
5. **Modular Systems**: Each system isolated and replaceable

### **Interaction Rules:**
- **Arms Always Accurate**: Point exactly where cursor is, always
- **Movement Deterministic**: Same input always produces same result
- **Camera Predictable**: Rail system eliminates camera confusion
- **Input Reliable**: Raw detection prevents Godot action mapping issues

---

## ✅ Current Status

### **Fully Implemented & Working:**
- ✅ Cardinal rail camera with 4-direction cycling
- ✅ Dual-arm IK with accurate cursor tracking
- ✅ Cardinal movement with facing-based A/D controls  
- ✅ Character facing system with visual indicators
- ✅ Entity2D5D rendering with SubViewport textures
- ✅ Comprehensive debug tools and coordinate tracking
- ✅ Mouse chording for tactical arm locking
- ✅ Consistent elbow bending in all directions

### **Ready for Next Features:**
- 🟡 Depth lane system (R/F keys for Z-axis stepping)
- 🟡 Stance system (L2/R2 for combat/work/rest stances)
- 🟡 Basic combat mechanics with formation gameplay
- 🟡 NPC entities using Entity2D5D base class

The foundation is solid and extensible for adding tactical gameplay features! 🎮