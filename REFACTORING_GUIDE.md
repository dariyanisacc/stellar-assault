# Stellar Assault Refactoring Guide

## Overview

The game has been refactored from a monolithic 7,500+ line `main.lua` file into a modular architecture with the following improvements:

### 1. Module Structure
```
/
├── main.lua              # Bootstrap and Love2D callbacks
├── src/
│   ├── constants.lua     # All game constants and magic numbers
│   ├── StateManager.lua  # State machine for game states
│   ├── player_control.lua  # Player input and movement
│   ├── enemy_ai.lua        # Basic enemy behaviors
│   ├── powerup_handler.lua # Powerup logic
│   └── objectpool.lua    # Object pooling for performance
└── states/
    ├── menu.lua          # Main menu state
    ├── intro.lua         # Intro/backstory state
    ├── playing.lua       # Main gameplay state
    ├── pause.lua         # Pause menu state
    ├── gameover.lua      # Game over state
    └── options.lua       # Options/settings state
```

The playing state is now split into `src/player_control.lua`, `src/enemy_ai.lua` and `src/powerup_handler.lua`.
### 2. Key Improvements Implemented

#### ✅ Modular Architecture
- Separated concerns into focused modules
- Each state is self-contained with its own update/draw logic
- Shared resources (fonts, audio) loaded once in main.lua

#### ✅ State Machine
- Clean state transitions without nested if/else chains
- Each state has enter/leave/update/draw methods
- Easy to add new game states

#### ✅ Constants Configuration
- All magic numbers moved to `src/constants.lua`
- Easy to tweak game balance
- Grouped by domain (player, laser, asteroid, etc.)

#### ✅ Object Pooling
- Implemented pools for lasers, explosions, and particles
- Reduces garbage collection pressure
- Better performance on mobile devices

#### ✅ Performance Optimizations
- Cached Love2D module lookups (lg, la, etc.)
- Pre-allocated object pools
- Efficient collision detection ready for spatial partitioning

### 3. Migration Notes

The original `main.lua` is backed up as `main_original.lua`. The new architecture maintains compatibility with existing save files and settings.

### 4. Next Steps

Remaining tasks from the refactoring checklist:

1. **Spatial Partitioning for Collisions**
   - Implemented a spatial hash grid (`src/spatial.lua`)
   - Collision loops in the main game and `WaveManager` now query this grid

2. **Frame-Rate Independence**
   - Audit all movement/timer code for dt usage
   - Ensure consistent behavior at different frame rates

3. **Debug Console**
   - Add command system for testing (F3 shows debug info)
   - God mode, spawn commands, etc.

4. **Function Decomposition**
   - Break down remaining large functions in states
   - Improve testability

5. **Boss System Refactor**
   - Move boss logic to separate module
   - Data-driven boss patterns

### 5. Testing the Refactored Code

Run the game normally:
```bash
love .
```

The game should behave identically to the original, but with:
- Cleaner code organization
- Better performance
- Easier maintenance
- Simpler to add new features

### 6. Adding New Features

To add a new game state:
1. Create `states/newstate.lua`
2. Register in `main.lua`: `stateManager:register("newstate", require("states.newstate"))`
3. Switch to it: `stateManager:switch("newstate")`

To add new constants:
1. Edit `src/constants.lua`
2. Access via `constants.category.value`

To use object pooling:
1. Create pool: `local pool = ObjectPool:new(createFunc, resetFunc)`
2. Get object: `local obj = pool:get()`
3. Release object: `pool:release(obj)`
