# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a 2.5D game built in Redot 4.3 (fork of Godot) featuring a complex dual-arm control system and solipsistic rendering architecture. The game uses a unique coordinate system where the player's consciousness is the fixed center point of reality.

## Key Architecture

### Solipsistic Coordinate System
- **Core Singleton**: `SolipsisticCoordinates` manages the reality manifestation system
- **Player-Centric Reality**: All entities exist in virtual space but only manifest when within the player's perception radius (500m)
- **Performance Optimization**: Only manifested entities run expensive visual/audio systems
- **Cardinal Orientations**: 4 viewing angles (EAST, SOUTH, WEST, NORTH) with coordinate transformation matrices

### Entity System
- **ProceduralEntity**: Base class for all procedurally drawn entities (no sprites)
- **VirtualEntity**: Manages manifestation state and autonomous behavior
- **SolipsisticPlayer**: Main player class with dual-arm IK control
- **Drawing System**: Everything is rendered procedurally using draw commands

### Input Architecture
- **Modular Input System**: Separate classes for MouseKeyboard and Controller input
- **Dual-Arm Control**: Independent left/right arm control via mouse buttons or controller triggers
- **Cardinal Movement**: A/D movement along current facing direction, Q/E for 90-degree rotation
- **Z-Layer Movement**: Discrete depth stepping for 2.5D gameplay

### World Systems
- **TerrainSystem**: Height-based terrain with 0.25m resolution grid
- **TerrainRenderer**: Handles procedural terrain drawing
- **2.5D Cardinal Rail Camera**: Fixed camera orientations that follow movement axis

## Common Development Commands

Since this is a Godot/Redot project, development primarily happens in the editor. The project file is `project.godot` and the main scene is `main_2d.tscn`.

## Code Conventions

- **GDScript**: All scripts use `.gd` extension
- **Class Names**: Use PascalCase (e.g., `SolipsisticPlayer`, `TerrainSystem`)
- **Coordinate System**: 20 units = 1 meter scale consistently throughout
- **Debug Control**: Master debug control via `SolipsisticCoordinates.DEBUG_ENABLED`
- **Entity Inheritance**: All drawable entities extend `ProceduralEntity`

## Important Design Principles

- **No Sprites**: Everything is drawn procedurally using `_draw()` functions
- **Skill-Based Gameplay**: Manual dexterity matters more than stats
- **Dual-Arm Independence**: Each arm can perform different actions simultaneously
- **Physics-Based**: Realistic force calculations for combat and interaction
- **Cardinal Movement**: Discrete 90-degree rotations, no smooth camera transitions

## Scene Structure

The main scene (`main_2d.tscn`) has a layered structure:
- **BackgroundLayer** (layer -10): Background elements
- **EntityLayers** (layer 0): Game entities including player
- **UILayer** (layer 10): HUD and interface elements

## Key Files to Understand

- `solipsistic_coordinates.gd` - Core singleton managing reality manifestation
- `solipsistic_player.gd` - Main player controller with dual-arm IK
- `procedural_entity.gd` - Base class for all drawable entities
- `terrain_system.gd` - Height-based terrain generation
- `Game Features Archive.md` - Comprehensive design document

## Modified Files Context

The current working state shows modifications to core systems:
- `solipsistic_coordinates.gd` - Coordinate system updates
- `solipsistic_player.gd` - Player controller refinements  
- `terrain_renderer.gd` - Terrain drawing improvements
- `terrain_system.gd` - Terrain generation updates

When working with these files, maintain the established patterns for coordinate transformation, procedural drawing, and the solipsistic reality system.