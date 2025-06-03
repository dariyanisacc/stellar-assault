# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Stellar Assault is a Love2D-based endless runner space game where players dodge asteroids and fight alien UFOs. The game is written in Lua and uses the Love2D game framework.

## Development Commands

### Running the Game
```bash
love .
```

### Running Tests
```bash
# Run all tests using busted
busted

# Or use the test runner script
./run_tests.lua

# Run specific test categories
busted -t unit
busted -t integration

# Run individual test files
busted tests/unit/collision_test.lua

# Run tests with code coverage
busted --coverage
luacov  # Generate coverage report
```

### Test Framework Requirements
- Install busted: `luarocks install busted`
- Install luacov (optional): `luarocks install luacov`

## Architecture Overview

### Core Game Loop
The game follows Love2D's standard callback structure with all game logic in `main.lua`:
- `love.load()` - Initializes game state, player, enemies, audio, and graphics
- `love.update(dt)` - Handles game logic, physics, collisions, and state transitions
- `love.draw()` - Renders all game elements based on current game state
- `love.keypressed()` / `love.keyreleased()` - Keyboard input handling
- `love.mousepressed()` - Mouse input for menus
- `love.gamepadpressed()` / `love.gamepadreleased()` - Controller support

### Game States
The game manages several states through the `gameState` global variable:
- `"menu"` - Main menu with Start/Options/Quit
- `"playing"` - Active gameplay
- `"paused"` - Pause menu
- `"gameOver"` - Game over screen
- `"options"` - Settings menu (resolution, audio, display mode)

### Key Game Systems

1. **Entity Management**: Game entities (player, asteroids, aliens, lasers, powerups) are stored in global tables and updated/drawn each frame

2. **Collision Detection**: Uses AABB (Axis-Aligned Bounding Box) collision detection via the `checkCollision()` function

3. **Level Progression**: Levels increase difficulty by adjusting spawn rates and introducing boss battles at level milestones

4. **Audio System**: Manages background music and sound effects with volume controls

5. **Power-up System**: Temporary abilities (shields, rapid fire, multi-shot) with visual feedback

6. **Boss Battles**: Special encounters at levels 5, 10, 15, etc. with unique attack patterns

### Testing Architecture
- Unit tests for core functions (collision detection, game state, player mechanics)
- Mock Love2D framework (`tests/mocks/love_mock.lua`) for testing without graphics
- Test organization: `tests/unit/`, `tests/integration/`, `tests/mocks/`

## Key Global Variables
- `gameState` - Current game state
- `player` - Player ship object
- `asteroids`, `aliens`, `lasers`, `alienLasers` - Entity arrays
- `activePowerups` - Active power-up effects
- `boss` - Boss entity (when spawned)
- Audio objects for sound effects and music