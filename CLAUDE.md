# CLAUDE CONTEXT PRESERVATION FILE

## IMPORTANT SYSTEM INFORMATION
- **Redot Engine Location**: `/usr/bin/Redot` (not lowercase "redot")
- **Working Directory**: `/home/ad/Game/core`
- **Project Type**: 2D Procedural Character Editor for Redot 4.3 beta
- **Window Size**: 1680x1080 (optimal for UI layout)

## ENTITY EDITOR ARCHITECTURE OVERVIEW

### Core Components
1. **EntityEditor.gd** - Main controller script with comprehensive documentation
2. **BodyPart.gd** - Resource class for polygon-based body parts with biological layers
3. **LayerData.gd** - Resource class for biological layer properties (thickness, material, quality)
4. **VariabilityZone.gd** - Resource class for muscle/fat expansion zones
5. **RotationConstraint.gd** - Resource class for joint rotation limits

### Key Features Implemented
- ✅ Smart polygon editing (click near edges to add points, click inside to move parts)
- ✅ Biological layer system with 8 layers (equipment→armor→clothes→outer→skin→meat→bone→organs)
- ✅ Parent-child attachment system with green/yellow attachment points
- ✅ Variability zone painting (Ctrl+Z to toggle, paint by clicking)
- ✅ Template save/load system (Ctrl+S to save, Ctrl+L to list)
- ✅ Joint rotation constraints with visual feedback
- ✅ Layer-based color coding and thickness visualization

### Current Bug Fixes Applied
- Fixed null pointer errors in layer system by adding null checks
- Fixed selected_body_part null access issues
- Prioritized edge clicking over whole-part movement for better UX

### Keyboard Shortcuts
- **Ctrl+Z**: Toggle variability zone painting mode
- **Ctrl+C**: Clear all variability zones (when in zone painting mode)
- **Ctrl+S**: Save current entity as template
- **Ctrl+L**: List available templates
- **Ctrl+G**: Toggle measurement grid on/off
- **Ctrl+R**: Reset zoom and pan to default view
- **Ctrl+D**: Clone selected body part
- **Escape**: Exit zone painting mode

### Mouse Interactions
1. **Click on attachment points** (green/yellow circles): Move attachment points
2. **Click on polygon points** (white circles): Move individual points
3. **Click near polygon edges**: Add new points between closest nodes
4. **Click inside polygon**: Move entire part
5. **Click on empty canvas**: Pan the view by dragging
6. **Click grid button** (bottom-left corner): Toggle grid visibility
7. **Right-click on points**: Delete points (minimum 3 required)
8. **Right-click in zone painting mode**: Delete variability zones at cursor position
9. **Mouse wheel up/down**: Zoom in/out at cursor position
10. **Middle mouse drag**: Alternative pan method

### Template System
- Saves to `user://templates/` directory as JSON files
- Serializes all polygon points, layers, variability zones, and relationships
- Maintains parent-child hierarchy when loading
- Includes creation timestamps

### File Structure
```
/home/ad/Game/core/
├── project.godot
├── scenes/
│   ├── Main.tscn (contains EntityEditor instance)
│   └── EntityEditor.tscn (main UI layout)
└── scripts/
    ├── EntityEditor.gd (main controller - 1100+ lines)
    ├── BodyPart.gd (body part resource)
    ├── LayerData.gd (biological layer data)
    ├── VariabilityZone.gd (expansion zones)
    └── RotationConstraint.gd (joint constraints)
```

### Testing Status
- ✅ Project loads without critical errors (fixed null pointer bugs)
- ✅ UI layout renders correctly at 1680x1080
- ✅ Canvas drawing system works properly
- ✅ Save/load template system implemented with comprehensive debugging
- 🔄 **READY FOR MANUAL TESTING**: Save/load, zone painting, polygon editing

### Debug Features Added
- Comprehensive debug output for save/load operations
- Templates save to `user://templates/` directory as JSON
- Full serialization of polygon points, layers, variability zones, relationships
- Load system maintains parent-child hierarchies and UI state

### Manual Testing Instructions
1. **Create Entity**: Add a body part, edit its shape by clicking near edges
2. **Test Cloning**: Select a part, click "Clone" button (or Ctrl+D) to duplicate it
3. **Test Zone Painting**: Press Ctrl+Z, click inside polygon to paint zones
4. **Test Save**: Enter name in "Template Name" field, click "Save" button (or Ctrl+S)
5. **Test Load**: Select template from list, click "Load" button
6. **Test Movement**: Click inside polygon to move parts, click edges to add points
7. **Test Attachments**: Click green/yellow circles to move attachment points
8. **Test Layers**: Change layer dropdown, adjust thickness/quality sliders

### NEW: Template UI Panel
- **Template Name Field**: Enter custom names for your templates
- **Save Button**: Saves current entity with the specified name
- **Load Button**: Loads the selected template from the list
- **Delete Button**: Deletes the selected template permanently
- **Template List**: Shows all available templates, click to select
- **Auto-naming**: If no name is provided, generates timestamp-based name

### NEW: Zone Deletion Feature
- **Right-click in zone painting mode**: Deletes variability zones at cursor position
- Works by detecting which zone contains the cursor and removing it
- Provides console feedback when zones are deleted

### NEW: Measurement Grid System
- **Scale Reference**: 1 grid unit = 1 decimeter (10cm) for realistic character scaling
- **Minor Grid Lines**: Light gray decimeter marks for fine positioning
- **Major Grid Lines**: Darker lines every meter (10 decimeters) for major measurements
- **Origin Axes**: Bright lines marking the center (0,0) position
- **Grid Toggle Button**: Visual button in bottom-left corner with grid icon
- **Toggle Methods**: Click button OR press Ctrl+G to show/hide the grid
- **Visual Feedback**: Button appears highlighted when grid is active
- **Zoom Aware**: Grid scales with zoom level for consistent visual reference
- **Use Case**: Create realistic human proportions (average adult ~17-18dm tall)

### NEW: Zoom and Pan System
- **Mouse Wheel Zoom**: Zoom in/out from 10% to 500% at cursor position
- **Canvas Drag Pan**: Click and drag empty canvas to pan the view
- **Middle Mouse Pan**: Alternative drag method to move the view around
- **Smart Zoom**: Keeps the point under cursor stationary while zooming
- **Consistent UI Elements**: Nodes, lines, and UI stay same size at all zoom levels
- **Grid Integration**: Grid scales properly while maintaining visual consistency
- **Reset View**: Ctrl+R returns to 100% zoom and centered position
- **High Precision**: Accurate coordinate tracking at all zoom levels
- **No Drift**: Points maintain exact positions during zoom/pan operations

### Code Quality Notes
- All critical functions have null checks to prevent crashes
- Comprehensive inline documentation throughout EntityEditor.gd
- Clear separation of concerns: drawing, interaction, serialization
- Defensive programming with fallback behaviors for missing UI elements

### Temporarily Disabled Features
- **Joint Rotation Constraints**: Visualization disabled until UI controls are implemented
- **Constraint Angle Lines**: Hidden to avoid zoom/pan transformation issues
- **Constraint UI Updates**: Commented out until proper implementation
- **Parent-Child Connection Lines**: Disabled until coordinate transformation is fixed (cyan arrows)