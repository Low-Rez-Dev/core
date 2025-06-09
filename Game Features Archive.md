# Game Features Archive

## Core Game Design
- **Engine**: Redot 4.3 (fork of Godot)
- **Perspective**: 2.5D - Side view with discrete Z-axis movement
- **Focus**: Complex dual-arm control system

## World & Visual Design
### 3D Grid System
- Discrete 1-meter increments on all axes
- Cardinal orientation system (E-W/N-S views)
- D-pad Left/Right rotates camera 90 degrees
- D-pad Up/Down moves through Z-axis depth layers

### Art Style
- 2D paper doll/cutout entities in 3D space
- 3D terrain and water bodies for spatial context
- Progressive bokeh blur for background Z-layers
- Gaussian blur + transparency for foreground entities
- Cutouts always face current camera orientation

## Ki Energy System
### Unified Life/Death Energy
- Single Ki bar with positive (life) and negative (death) portions
- Bar empties to minimum threshold, not zero (death occurs when minimum reached)
- Natural regeneration over time, accelerated by food, rest, healing magic

### Character Types
- **Mortals**: Mostly positive Ki with small death reserve
- **Undead**: Mostly negative Ki with small life reserve  
- **Benevolents**: Pure positive Ki (minimum = death threshold, e.g. 300)
- **Malevolents**: Pure negative Ki (minimum = death threshold, e.g. 75)

### Energy Consumption & Switching
- Primarily consume dominant energy type
- Balanced characters can consciously choose energy polarity
- Extended use of one polarity grows that capacity, cannibalizing the other
- Mortals using death energy long-term become undead (reversible with sustained positive energy)

### Death & Revival Mechanics
- **Benevolents**: Turn to stone (hardness = minimum life points), revived by positive healing
- **Malevolents**: Explode (force = minimum death points), leave soul stone, revived by nearby kill/sacrifice
- **Mortals/Undead**: Standard death when Ki reaches minimum threshold

## Dual-Arm Control System
### Combat Applications
- Each arm controlled independently (left/right mouse buttons or triggers)
- Block with shield while keeping javelin cocked and ready
- Shield bash while positioning sword arm for strike
- Melee weapons: swords, spears, shields
- Ranged: bows, javelins, throwing items
- Improvised weapons and tools as weapons
- Predictive trajectory arcs for throwing/ranged attacks
- Grappling hooks

### Work/Crafting Applications
- Digging, ploughing, mining
- Forging: making molds, shaping hot metal billets
- Pottery: shaping on spinning wheel
- All crafting uses dual-arm motions
- Quality based on manual skill execution, not stats
- Custom items with unique stats/appearance based on crafting performance

## Input Systems
### Mouse & Keyboard
- Left/Right mouse buttons activate respective arms
- Mouse position controls arm targeting/direction
- Recording functionality for muscle memory system
- A/D movement along current cardinal axis
- Q/E rotation between cardinal orientations
- Mouse chording for tactical arm locking

### Controller Support
- L/R triggers activate respective arms (analog pressure)
- L/R joysticks control respective arms when triggers held
- L/R shoulder buttons for action recording
- D-pad Up/Down: Z-axis movement through depth layers
- D-pad Left/Right: Rotate camera orientation (90-degree increments)
- When triggers released:
  - Left stick = character movement
  - Right stick = focus direction

## Technical Implementation
### 2.5D Cardinal Rail Camera System
- **4 Cardinal Orientations**: Camera locked to cardinal positions, follows movement axis
- **Rail Following**: Camera slides parallel to Movement Axis, maintains fixed distance
- **Hard Cardinal Snapping**: Instant 90° rotations, no smooth camera transitions
- **Movement-Depth Integration**: 
  - Camera rail runs parallel to current Movement Axis
  - Depth Axis changes provide tactical Z-positioning
  - Q/E rotation affects entire player+camera+axis system together

### Entity2D5D Rendering System
- Base class for all 2D entities in 3D space
- SubViewport texture rendering for 2D characters
- Sprite3D display in 3D world with proper scaling
- Always face camera orientation with discrete Z-positioning

### Coordinate & Navigation Systems
- **3D Grid System**: Discrete 1-meter increments with cardinal orientation
- **Dual-Axis Movement**: Movement Axis (free analog) vs Depth Axis (discrete lanes)
- **Grid Reference**: X0=Prime Meridian, Z0=Equator
- **Coordinate Conversion**: Degrees/minutes/seconds/milliseconds display format
- **Real-time HUD**: Position, current movement/depth axes, camera orientation
- **Axis Relationships**:
  - Facing East/West: X=Movement Axis, Z=Depth Axis  
  - Facing North/South: Z=Movement Axis, X=Depth Axis

### Movement System
- **Dual-Axis System**: Current cardinal facing determines Movement vs Depth axes
- **Movement Axis**: Free analog movement along facing direction (A/D keys)
- **Depth Axis**: Discrete 1-meter lane stepping perpendicular to movement (D-pad Up/Down)
- **Cardinal Rotation**: Q/E swaps which world axis serves as Movement vs Depth
- **Speed Control**: Walking (1.5 m/s) vs running (4.0 m/s) on Movement Axis
- **Tactical Applications**:
  - Formation combat: Smooth positioning within ranks
  - Lane changes: Discrete stepping between battle lines
  - Building navigation: Fluid room movement, discrete floor changes

### Body Controller & IK System
- Inverse kinematics using law of cosines for realistic arm movement
- Proportional body scaling with adjustable parameters
- Facing-dependent elbow positioning
- Arm reach limiting and natural joint positioning
- Rest positions at hip level with facing-aware adjustments

## Combat & Damage Systems
### Physics-Based Damage
- **Force Calculation**: (Muscle Strength × Technique Efficiency) + (Weapon Mass × Swing Speed) + Momentum Transfer
- **Armor Hardness Thresholds**: Materials require specific force levels to penetrate
- **Damage Distribution**:
  - Below threshold: 100% force damages armor durability
  - Above threshold: Excess force damages character, armor still degrades
  - Blunt force: Always does reduced damage through armor
- **Grip Strength**: Affects energy transfer efficiency and disarming resistance

### Dismemberment & Medical Systems
- **Dismemberment Mechanics**: Massive force thresholds, joint targeting, sharp weapon bonuses
- **Medical Consequences**: Ki loss from bleeding, shock effects, field medicine with tourniquets
- **Setting-Specific Recovery**:
  - Hot Gates/Jade Mountain: Permanent character limitation
  - Age of Titans: Tribal succession, spiritual compensation
  - New Albion: Advanced sparkcraft prosthetics with runic interfaces

## Terrain & Navigation Systems
### Terrain Design Philosophy
- **Smooth Within Blocks**: Gentle slopes, no sudden height changes within 1-meter grid blocks
- **Sharp Changes at Boundaries**: Dramatic height differences occur at exact lane boundaries
- **Ant Farm Cross-Sections**: Each depth lane shows clean terrain slice from current camera angle

### Special Terrain Types
**Stair Blocks:**
- **Camera-Dependent Behavior**: 
  - Front view: Platform mechanics (jump up/down, Down+Jump to drop through)
  - Side view: Normal terrain surfaces for leg IK
- **Default Position**: Bottom step when entering stair block
- **Ascent Methods**: Jump or D-pad Up to climb
- **Same Lane Navigation**: No depth changes needed when viewed from front

**Moveable Ladders:**
- **Cardinal Placement Only**: North, East, South, West orientations
- **Height Bridging**: Connects blocks with different elevations
- **Dual Behavior**: Platform mode (front view) vs ramp mode (side view)
- **Player Moveable**: Can be repositioned and rotated for tactical/puzzle use

### Climbing & Rope Systems
**Rope Mechanics:**
- **Climb Stance**: L2/R2 to enter climbing mode
- **Alternating Arms**: L/R triggers for proper hand-over-hand technique
- **Grip Strength Control**: Tight grip for control, loose grip for sliding
- **Descent Options**: Controlled rappelling vs emergency fast sliding
- **Diagonal Zip-Lines**: Gravity-powered descent with speed control

**Grappling Hooks:**
- **Dual-Arm Throwing**: Wind up and trajectory control
- **Combat Applications**: Disarm shields, entangle weapons, tactical positioning
- **Traversal**: Wall scaling, gap crossing, quick descent
- **Physics Integration**: Rope tension, weight limits, environmental factors
- Focus cone from character head to cursor/right stick direction
- Sharp vision within focus cone
- Blurred vision at peripheries
- Static "dead reckoning" memory for areas outside vision
- Enables hidden object discovery and item identification
- Creates tactical awareness gameplay

## Advanced Systems (Future Implementation)

### Chakra System
- **Dual Polarity**: Each chakra has opposing emotional states with visual aura distinction
- **Geometric Progression**: Triangle (3), Square (4), Pentagon (5), Hexagon (6), Heptagon (7), Octagon (8) aspects per chakra
- **Ki Bandwidth Flow**: Bottom-up energy distribution, lower chakras can starve higher ones
- **Aura Reading**: Immediate urges (bright colors) vs personality aspects (subtle tints)
- **Color System**: Light/pastel vs dark/saturated indicating polarity, intensity shows activation level

**Root Chakra (Red/Pink Triangle):**
- Fear Pole: Fight, Flight, Freeze
- Calm Pole: Stand, Stay, Steady
- Personality Aspects: Hot-headed/Domineering, Evasive, Submissive
- Element Affinity: Earth (solids)

**Sacral Chakra (Orange Square):**
- Desire Pole: Collect, Create, Connect, Consume
- Apathy Pole: Discard, Destroy, Disconnect, Deny
- Personality Aspects: Greedy/Ascetic, Artistic/Destructive, Social/Hermitic, Hedonistic/Abstinent
- Element Affinity: Water (liquids)

**Solar Plexus Chakra (Yellow Pentagon):**
- Pride Pole: Boast, Brag, Bully, Boss, Belittle
- Shame Pole: Shrink, Submit, Stammer, Startle, Sulk
- Personality Aspects: Arrogant/Timid, Domineering/Submissive, Showoff/Anxious, Tyrant/Startled, Critic/Depressive
- Element Affinity: Fire (plasma)

**Heart Chakra (Green Hexagon):**
- Love Pole: Like, Love, Laugh, Listen, Lift, Link
- Hate Pole: Hurt, Harm, Hate, Harass, Hinder, Humiliate
- Personality Aspects: Compassionate/Bitter, Nurturing/Cruel, Empathetic/Vengeful, Supportive/Hostile, Loving/Spiteful, Accepting/Divisive
- Element Affinity: Air (gases)

**Throat Chakra (Blue Heptagon):**
- Truth Pole: Tell, Teach, Testify, Talk, Trust, Transmit, Trumpet
- Lies Pole: Silence, Suppress, Secrete, Slander, Stifle, Smother, Sabotage
- Element: Space (teleportation to named/known places)
- Personality Aspects: Honest/Deceptive, Eloquent/Secretive, Teacher/Manipulative, Communicator/Silent, Truthful/Slanderous, Expressive/Suppressive, Inspiring/Scheming

**Third Eye Chakra (Indigo Octagon):**
- Insight Pole: Perceive, Ponder, Probe, Predict, Process, Piece-together, Penetrate, Purify
- Delusion Pole: Confuse, Cloud, Corrupt, Complicate, Conceal, Contradict, Clash, Chaos
- Element: Mind (astral projection, aura reading, temporal effects in single-player)
- Personality Aspects: Wise/Paranoid, Perceptive/Confused, Intuitive/Delusional, Analytical/Obstinate, Visionary/Blind, Mystic/Manic, Seer/Scattered, Oracle/Mad

### Elemental Magic System
- **Physical State Mastery**: Earth (solids), Water (liquids), Air (gases), Fire (plasma)
- **Equal Difficulty**: No element inherently harder, character affinity determines starting ease
- **Single Element Specialization**: Characters can only master one element completely
- **Chakra Affinities**: Root→Earth, Sacral→Water, Solar Plexus→Fire, Heart→Air, Throat→Space, Third Eye→Mind
- **Dual-Arm Integration**: Each hand can channel elemental manipulation independently

### Platonic Forms Crafting
- **Intent Declaration**: Hierarchical thought bubble menu (furniture → seating → chair → dining chair)
- **Ideal Form Overlay**: Semi-transparent outline of "perfect" version appears on work surface
- **Top-Down Work View**: Precision placement interface showing work table/floor area
- **Material Preparation**: Bring raw materials to designated crafting area
- **Dual-Arm Construction**: 
  - Left hand holds/positions materials
  - Right hand operates tools (saw, hammer, drill, etc.)
  - Coordinated motions for complex joins and cuts
- **Quality Factors**:
  - Tool sharpness/quality affects cut precision
  - Material quality influences durability and appearance
  - Join type (nails, glue, slots, wrapping) impacts structural integrity
  - Proximity to Platonic ideal affects functionality and stats
- **Custom Type Creation**: Items that don't fit existing categories can be named by player, added to crafting menu
- **Game Progression**:
  - Hot Gates: Survival crafting (weapons, tools, camp equipment, field repairs)
  - Jade Mountain: Full artistic system (furniture, pottery, ceremonial objects)
  - Age of Titans: Primitive spiritual crafting
  - New Albion: Advanced technomagical construction

### Routine/Habit System
- **Daily Task Recording**: Automate mundane activities (cooking, cleaning, work)
- **NPC Behavior**: Habit patterns influenced by chakra personality aspects
- **Muscle Memory Extension**: Long-term behavioral patterns beyond combat techniques
- **Interruption Events**: Important occurrences break routine appropriately
- **Game Introduction**: Simple version in Hot Gates (weapon maintenance, formation drills, mess duties)

### Ecological Simulation
- **Biome Emotional States**: Collective wildlife chakra median affects environmental aura colors
- **Megafauna Hierarchy**: Elder animals with higher chakra access (4-5 chakras vs 1-2 for young)
- **Animal Transcendence**: Ancient matriarchs/patriarchs can become benevolents (stone statues) or malevolents (exploding, soul stones)
- **Spirit Manifestations**: Biome health creates/destroys nature spirits and forest guardians
- **Ki Corruption**: Animal tribes and ecosystems can become undead through death energy exposure
- **Territorial Claims**: Animal packs and herds mark territories similar to human factions
- **Elder Negotiation**: Spiritually developed players can communicate with animal patriarchs/matriarchs
- **Corruption Cascades**: Undead tribes spread corruption to neighboring ecosystems

### Tribal/Generational System
- **Inheritance Gameplay**: Continue as heir upon character death
- **Knowledge Transfer**: Teach children skills, habits, and chakra control techniques
- **Settlement Growth**: Individual → family → village → tribe progression
- **Presence-Based Territories**: Areas tinted by faction use, from core (strong) to periphery (weak)
- **Natural Decay**: Unused areas fade back to neutral over time
- **RTS Elements**: High influence allows direct control of multiple tribe members
- **Territorial Conflicts**: Overlapping claims create natural diplomatic tensions
- **Environmental Storytelling**: Territorial layers tell the story of past activities

### Built-in Action Systems
**Core Throwing Mechanics:**
- **Built-in Patterns**: System provides proper biomechanics automatically
- **Prediction Arc**: Skill-based accuracy of trajectory preview
- **Progressive Learning**: Practice improves arc precision
- **Weapon Integration**: Javelins, rocks, grappling hooks, improvised projectiles

**Equipment-Dependent Stances:**
- **Tool Requirements**: Stances only available with appropriate equipment
- **Targeting Categories**: Combat (enemies), Woodcutting (trees), Mining (ore), Harvesting (crops)
- **Collision Layer Control**: Stance determines valid interaction targets
- **Multi-Tool Capability**: Primitive tools unlock multiple stances (hand axe for combat/woodcutting/crafting)

### Body Composition System
**Layered Anatomy (Outside to Inside):**
1. **Armor**: Metal/leather protection
2. **Clothes**: Fabric coverings  
3. **Outer Layer**: Fur (mammals), Feathers (birds), Scales (reptiles/fish)
4. **Skin**: Hide/leather source
5. **Meat**: Food and sustenance
6. **Bone**: Tools, weapons, structure
7. **Organs**: Heart, liver, brain (location-specific)

**Damage & Resource System:**
- **Layer Penetration**: Damage propagates through layers based on force
- **Butchering Stance**: Required for proper carcass processing
- **Material Quality**: Undamaged parts yield superior materials
- **Species Variation**: Different animals provide unique material properties
- **Processing Techniques**: Dual-arm harvesting with skill requirements

**Game Progression:**
- **Hot Gates**: Earth animals, basic materials
- **Jade Mountain**: Medicinal/spiritual applications
- **Age of Titans**: Megafauna with massive material yields
- **New Albion**: Procedural alien biology with exotic technomagical materials
- Indicates intention and available move sets
- Controls collision layers for context-appropriate interactions
- **Stance Types**:
  - Relaxed: Basic interactions, environment inspection
  - Battle: Combat ready, collides with enemies
  - Hunting: Targets game animals
  - Woodcutting: Axe collides with trees only
  - Mining: Tool interactions with ore/stone
  - Crafting: Precision work positioning
  - Guarded: Defensive but still interactive
- **Resting Postures**: Default arm positions when inactive
  - Shield up and ready to block (sword & shield)
  - Two-handed weapon ready to parry
  - Axe ready to chop (woodcutting)
- **Automatic Triggers**: Stance shifts based on environment
  - Threat detection → Guarded stance
  - Loud noises → Alert positioning
  - Enemy proximity → Battle ready
- User-customizable stance programming
- Default stances available for NPCs and animals
- **L2/R2 Control**: Cycle through stances with shoulder buttons

### Muscle Memory System
- **Relative Movement Recording**: Records semantic movements like [retract arm][away from][enemy]
- **Contextual Actions**: [extend arm][towards][enemy] for thrusts, adaptable to different situations
- **Grasp State Tracking**: [parallel/perpendicular to forearm], [swing from perpendicular to parallel]
- **Stance-Specific Mapping**: Same gesture means different actions in different stances
- **Combat Applications**:
  - Sword: arm up + perpendicular grip = overhead slash
  - Bow: arrow arm back + parallel grip = draw bowstring
  - Spear: retract + extend sequence = thrust attack
- **Weapon Adaptation**: Recorded techniques work across similar weapon types
- **Teaching Integration**: Players learn semantic meaning, not just muscle motion
- **Grip Strength Integration**: Affects disarming resistance and stamina usage

### Knowledge Transfer System
- **Technique Demonstration**: Players record complex motions and show them to others
- **Visual Learning**: Speech bubbles or visual demonstrations of recorded techniques
- **Social Learning**: Character observation and mimicry of witnessed skills
- **Skill Transfer**: Actual technique transfer between players, not just stats
- **Muscle Memory Integration**: Learned techniques become part of personal muscle memory system

## Design Philosophy
- **Skill-based gameplay** over stat-based progression
- **Unique, player-created items** encouraged through Platonic Forms system
- **Social learning and knowledge sharing** between players
- **Manual dexterity and timing** matter more than character levels
- **Focus on core mechanics** before feature expansion
- **Emergent culture creation** through crafting, naming, and territorial systems
- **Meaningful player legacy** through custom item types and knowledge transfer

## Game Series Progression
1. **The Hot Gates** - Spartan combat foundation, basic survival crafting
2. **Jade Mountain** - Xiaolin spiritual mastery, full crafting system, chakra development  
3. **Age of Titans** - Primordial cosmic forces, elemental magic, tribal/ecological systems
4. **New Albion** - Technomagical space exploration, advanced crafting integration

## Aesthetic Progression
- **The Hot Gates**: Greek pottery pixel art - bold black figures, geometric patterns
- **Jade Mountain**: Eastern scroll pixel art - misty mountains, flowing robes, detailed architecture
- **Age of Titans**: Moebius-inspired pixel art - cosmic landscapes, flowing linework, psychedelic elements
- **New Albion**: Friendly WH40K pixel art - noble space knights, cyan/purple palette, heraldic symbols

## New Albion Terminology (Anglish)
### Computing & Technology
- **Reckoner** - computer
- **Reckon gem** - processor/CPU
- **Runeblock** - data storage device
- **Runewright** - software developer/programmer
- **Sparkcraft** - electricity
- **Sparkways** - electrical conduits/wires
- **Thinkwright** - computer/hardware engineer

### Materials & Equipment
- **Ironstone** - metal ore (with color coding: grey/red/white/yellow)
- **Wardplate** - powered armor/knightly power armor
- **Glowbrand** - power sword/energy sword
- **Lodestone** - natural magnet/magnetic ore
- **Lodefield** - magnetic field

## Current Implementation Status
### ✅ **Core Systems Implemented**
- **2.5D Cardinal Rail Camera System** - 4 cardinal orientations with locked directions
- **Dual-Arm IK Control System** - Independent arm control with inverse kinematics
- **Cardinal Movement System** - Orientation-aware A/D movement with Q/E rotation
- **Entity2D5D Rendering System** - 2D characters in 3D space via SubViewport
- **Modular Input System** - MouseKeyboard and Controller input with chording support
- **Coordinate & Navigation Systems** - Real-time HUD with grid reference
- **Debug & Development Tools** - Comprehensive diagnostics and emergency recovery

### 🚀 **Ready for Implementation**
- **Terrain System**: Smooth block-based terrain with special stair/ladder mechanics
- **Leg IK**: Ground contact for slopes and uneven surfaces
- **Stance System**: L2/R2 controls with equipment-dependent availability
- **Built-in Actions**: Throwing mechanics with prediction arcs
- **Basic Combat**: Equipment-based stance targeting with force calculations
- **Body Composition**: Layered anatomy system for realistic damage and harvesting