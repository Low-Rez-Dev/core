# Entity Composition System

## Overview
The Entity Composition System provides a unified framework for creating, managing, and interacting with all entities in the game world. This system handles everything from player characters to animals to procedurally generated alien life forms, using a layered anatomy approach combined with modular polygon-based body construction.

## Core Data Structures

### BodyPart Class
```gdscript
class BodyPart:
    var part_name: String                    # "head", "torso", "left_arm", etc.
    var polygon_points: PackedVector2Array   # Shape definition
    var attachment_point: Vector2            # Where this part connects
    var parent_attachment: Vector2           # Where parent connects to this
    var variability_zones: Array[VariabilityZone]  # Muscle/fat expansion areas
    
    # Joint rotation constraints
    var rotation_limits: RotationConstraint = RotationConstraint.new()
    
    # Layered composition (outside to inside)
    var layers: Dictionary = {
        "equipment": {},                     # Backpacks, weapons, tools, belts, quivers
        "armor": null,                       # Metal/leather protection
        "clothes": null,                     # Fabric coverings
        "outer": null,                       # Fur/feathers/scales (species-dependent)
        "skin": LayerData.new(),            # Hide/leather source
        "meat": LayerData.new(),            # Food material
        "bone": LayerData.new(),            # Tool/weapon material
        "organs": {}                        # Heart, brain, etc. (location-specific)
    }
```

### RotationConstraint Class
```gdscript
class RotationConstraint:
    var min_angle: float                    # Minimum rotation angle (radians)
    var max_angle: float                    # Maximum rotation angle (radians)
    var rest_angle: float                   # Default/natural position
    var stiffness: float                    # Resistance to movement
    var constraint_type: String             # "hinge", "ball_socket", "fixed", "twist"
```
```gdscript
class LayerData:
    var material_type: String               # "leather", "iron", "fur", etc.
    var thickness: float                    # Physical depth of layer
    var quality: float                      # Material grade (0.0 - 1.0)
    var damage: float                       # Current damage level
    var volume: float                       # Calculated from polygon area × thickness
    var condition_modifiers: Dictionary     # Disease, enhancement, etc.
```

### VariabilityZone Class
```gdscript
class VariabilityZone:
    var zone_name: String                   # "muscle", "fat", "bone_growth"
    var affected_points: Array[int]         # Polygon point indices
    var expansion_factor: float             # Current expansion (1.0 = base)
    var max_expansion: float                # Genetic/physical limit
    var growth_rate: float                  # How fast this zone responds to stimuli
```

### LayerData Class
```gdscript
class EquipmentSlot:
    var slot_type: String                   # "weapon", "tool", "storage", "accessory"
    var attachment_point: Vector2           # Connection point on body part
    var equipped_item: Item                 # Current item in slot
    var visibility_layer: String           # Which layer occludes this slot
    var accessibility: float               # Draw speed modifier (belt vs backpack)
```

## Biological Classification Templates

### Taxonomic Auto-Population
When creating entities, selecting a biological class automatically populates appropriate body part slots:

**Plant:**
- trunk, branches, leaves, roots (if surface-visible)
- Outer layer: bark/skin only

**Mammal:**
- head, torso, 4 limbs, tail (optional)
- Outer layer: fur
- Full layer set: equipment → armor → clothes → fur → skin → meat → bone → organs

**Avian:**
- head, torso, 2 legs, 2 wings, tail
- Outer layer: feathers
- Layer set: equipment → armor → clothes → feathers → skin → meat → bone → organs

**Reptile/Fish:**
- head, torso, 4 limbs/fins, tail
- Outer layer: scales
- Layer set: equipment → armor → clothes → scales → skin → meat → bone → organs

**Amphibian:**
- head, torso, 4 limbs
- No outer layer (skin only)
- Layer set: equipment → armor → clothes → skin → meat → bone → organs

### Procedural Variation System
- **Parameter Ranges**: Set realistic bounds for each body part dimension
- **Genetic Inheritance**: Traits passed from parents with variation
- **Environmental Adaptation**: Morphology adapts to local conditions over generations
- **Nutritional Impact**: Current body condition affects fat/muscle zones
- **Age Scaling**: Same template scales from infant to adult

## Entity Editor

### Polygon Editing Interface
**Core Tools:**
- **Point Manipulation**: Add, remove, and adjust polygon vertices
- **Attachment Nodes**: Set precise pivot points for parent-child relationships
- **Joint Rotation Constraints:**
- **Limit Line Visualization**: Two draggable lines radiating from parent attachment node
- **Interactive Adjustment**: Drag line endpoints to set min/max rotation angles
- **Real-time Preview**: Selected body part rotates to show constraint boundaries
- **Constraint Types**: Hinge (elbow), ball socket (shoulder), fixed (skull), twist (wrist)
- **Natural Positioning**: Set rest angle for default pose

**Anatomical Accuracy:**
- **Species-Specific Limits**: Human elbow vs bird wing vs fish fin constraints
- **Bilateral Symmetry**: Mirror constraints across left/right body parts
- **Age Variations**: Infant vs adult joint flexibility differences
- **Injury Impact**: Damaged joints have reduced range of motion
- **Symmetry Tools**: Mirror changes across bilateral body parts

**Variability Zone Assignment:**
- **Zone Painting**: Select polygon points and assign to expansion categories
- **Growth Preview**: Test muscle/fat/age changes in real-time
- **Inheritance Mapping**: Set which zones are genetic vs environmental
- **Limit Setting**: Define maximum expansion for each zone type

**Layer Configuration:**
- **Material Assignment**: Set base materials for each anatomical layer
- **Thickness Mapping**: Define layer depth variations across body parts
- **Quality Distribution**: Set material grade variations
- **Species-Specific Setup**: Configure appropriate outer layer (fur/scales/feathers)

**Template Management:**
- **Save/Load System**: Store completed entity templates
- **Metadata Tagging**: Biological classification, size category, special traits
- **Version Control**: Track template revisions and improvements
- **Export Functions**: Generate runtime data structures from editor templates

### Procedural Population Tools
**Parameter Randomization:**
- **Slider Controls**: Set min/max bounds for each body dimension
- **Distribution Curves**: Control how traits vary across populations
- **Correlation Rules**: Link related traits (bigger body = stronger legs)
- **Mutation Rates**: How much offspring can vary from parents

**Environmental Presets:**
- **Climate Adaptation**: Cold = thicker fur, Desert = heat resistance
- **Predation Pressure**: High danger = speed/armor emphasis
- **Food Scarcity**: Limited resources = smaller, more efficient builds
- **Terrain Specialization**: Mountain climbers, forest dwellers, etc.

## Inventory System

### Body Part Grid Interface
**Visual Layout:**
```
[Layer Slider: Equipment | Armor | Clothes | Outer | Skin | Meat | Bone | Organs]

Body Part Grid:
[Head   ] [Neck  ] [     ] [     ] [     ]
[L.Arm  ] [Torso ] [R.Arm] [     ] [     ]
[       ] [L.Leg ] [R.Leg] [     ] [     ]
[       ] [L.Foot] [R.Foot] [    ] [     ]
```

**Layer Interaction Types:**

**Equipment Layer:**
- **Drag & Drop**: Equip/unequip items from inventory
- **Multiple Slots**: Body parts can have multiple equipment slots
- **Visual Feedback**: Show equipped items on character model
- **Stat Display**: Weapon damage, tool efficiency, storage capacity

**Armor Layer:**
- **Equipment Management**: Equip/remove armor pieces
- **Condition Monitoring**: Durability, damage resistance, weight
- **Material Properties**: Metal vs leather vs cloth protection values
- **Repair Interface**: Show damage and repair options

**Clothing Layer:**
- **Fashion/Function**: Both aesthetic and practical (warmth, pockets)
- **Layering Rules**: What can be worn over/under other items
- **Condition Tracking**: Wear, tear, cleanliness status
- **Cultural Significance**: Tribal markings, rank indicators

**Biological Layers (View-Only):**
- **Outer Layer**: Fur/feather/scale condition, grooming status
- **Skin**: Scarring, disease, tattoos, general health
- **Meat**: Muscle development, fat content, nutritional status
- **Bone**: Structural integrity, fractures, growth patterns
- **Organs**: Health status, function efficiency, diseases

### Information Display System

**Health Monitoring:**
- **Color Coding**: Green (healthy), Yellow (minor issues), Red (serious problems)
- **Progress Bars**: Healing over time, disease progression, growth
- **Detailed Tooltips**: Specific condition information and treatment options
- **Trend Indicators**: Improving/worsening conditions over time

**Material Assessment:**
- **Harvestable Quantities**: How much of each material this body part contains
- **Quality Ratings**: Grade of materials available (poor/average/excellent)
- **Processing Requirements**: Tools and skills needed for harvesting
- **Economic Value**: Trade worth of materials in current market

**Performance Metrics:**
- **Functionality**: How well this body part performs its role
- **Efficiency**: Energy cost vs output for this part
- **Coordination**: How well this part works with others
- **Potential**: Room for improvement through training/treatment

## Damage & Interaction System

### Damage Propagation
**Layer Penetration Rules:**
1. **Equipment**: First line of defense, tools/weapons can block/deflect
2. **Armor**: Primary protection layer, absorbs/distributes force
3. **Clothing**: Minor protection, mainly environmental
4. **Outer Layer**: Natural protection (scales/fur), varies by species
5. **Skin**: Injury threshold, scarring and healing mechanics
6. **Meat**: Tissue damage, bleeding, functional impairment
7. **Bone**: Structural damage, fractures, long-term disability
8. **Organs**: Critical damage, life-threatening injuries

**Force Distribution:**
- **Blunt Trauma**: Damage spreads across multiple layers
- **Piercing**: Damage concentrates through layers sequentially
- **Slashing**: Damage primarily to outer layers unless severe
- **Elemental**: Different damage types interact with materials uniquely

### Resource Harvesting
**Butchering Mechanics:**
- **Tool Requirements**: Specific tools needed for each layer
- **Skill Dependencies**: Technique affects yield and quality
- **Dual-Arm Process**: One hand holds, other cuts/processes
- **Damage Assessment**: Pre-existing damage reduces material quality
- **Time Investment**: Proper processing takes significant time

**Material Yields:**
- **Equipment**: Recoverable items (weapons, tools, valuables)
- **Armor**: Scrap materials, potentially repairable pieces
- **Outer Layer**: Pelts, hides, feathers for crafting
- **Skin**: Leather, cord, flexible materials
- **Meat**: Food, bait, alchemical components
- **Bone**: Tools, weapons, decorative items
- **Organs**: Medicine, cooking ingredients, ritual components

## Development & Gameplay Integration

### Character Progression
**Physical Development:**
- **Muscle Growth**: Strength training expands muscle zones
- **Fat Distribution**: Nutrition affects fat deposit areas
- **Bone Density**: Activity and diet influence bone strength
- **Skill Calluses**: Tool use creates specialized adaptations

**Equipment Mastery:**
- **Familiarity Bonuses**: Repeated use of equipment improves efficiency
- **Stance Availability**: Equipment determines available combat/work stances
- **Maintenance Skills**: Caring for equipment extends durability
- **Customization**: Modify equipment for personal fit and preferences

### Procedural Generation
**Runtime Population:**
- **Ecosystem Balance**: Generate appropriate predator/prey ratios
- **Environmental Pressure**: Climate and terrain influence creature design
- **Evolutionary Simulation**: Populations adapt over multiple generations
- **Player Impact**: Human activity affects local creature development

**Alien Biology (New Albion):**
- **Exotic Materials**: Silicon bones, crystalline scales, energy organs
- **Unusual Anatomy**: Multiple hearts, distributed nervous systems
- **Environmental Adaptations**: Vacuum tolerance, radiation resistance
- **Techno-Biological**: Integrated technology and biology

### Game Series Progression
**The Hot Gates:**
- **Basic Templates**: Human soldiers, horses, basic wildlife
- **Simple Layering**: Focus on equipment and armor systems
- **Survival Harvesting**: Basic butchering for food and materials

**Jade Mountain:**
- **Enhanced Biology**: Detailed health and spiritual condition tracking
- **Meditation Effects**: Chakra development affects physical condition
- **Medicinal Systems**: Herbal treatments and energy healing

**Age of Titans:**
- **Megafauna**: Massive creatures with proportionally scaled anatomy
- **Tribal Specialization**: Selective breeding for desired traits
- **Spiritual Integration**: Soul reincarnation affects physical development

**New Albion:**
- **Alien Encounters**: Completely novel biological systems
- **Genetic Engineering**: Technological manipulation of biological traits
- **Hybrid Technology**: Bio-mechanical integrations and enhancements
- **Interplanetary Variation**: Different evolutionary pressures per world