# Stellar Assault

A fast-paced endless runner space game built with Love2D where players dodge asteroids and fight alien UFOs across multiple unique levels.

## Features

- **5 Unique Levels**: Each with distinct themes, enemies, and challenges
  - Deep Space: Classic asteroid dodging with alien fighters
  - Nebula Zone: Environmental hazards and phase-shifting enemies
  - Ice Moon: Ground-based combat with turrets and hover tanks
  - Mothership Interior: Organic/mechanical hybrid enemies
  - Solar Core: Final boss battle with the Solar Overlord

- **Dynamic Gameplay**:
  - Progressive difficulty system
  - Boss battles at level milestones (levels 5, 10, 15, etc.)
  - Power-up system (triple shot, rapid fire, shields, time slow)
  - Combo system for chaining enemy defeats
  - Local high score tracking

- **Variety of Enemies**:
  - Basic UFOs, scouts, and heavy fighters
  - Level-specific enemies (ice turrets, nebula wraiths, fire elementals)
  - Unique boss encounters with multiple attack patterns

## Requirements

- [Love2D](https://love2d.org/) 11.0 or higher
- Lua 5.1+

## How to Run

1. Install Love2D from https://love2d.org/
2. Clone this repository:
   ```bash
   git clone git@github.com:dariyanisacc/stellar-assault.git
   cd stellar-assault
   ```
3. Run the game:
   ```bash
   love .
   ```

## Controls

- **Arrow Keys**: Move ship
- **Space**: Fire lasers
- **P**: Pause game
- **Escape**: Return to menu (when paused)
- **Mouse**: Navigate menus

## Game Mechanics

- Destroy asteroids and aliens to increase your score
- Collect power-ups dropped by destroyed enemies
- Build combos by defeating enemies in quick succession
- Survive waves of enemies to trigger boss battles
- Complete levels to unlock new environments and challenges

## Debugging

Press `~` to open or close the in-game debug console. Use **F3** to toggle
on-screen debug info (FPS, entity counts, etc.) and **F9** for the debug overlay
with memory graphs and other stats. **F5** hot‑reloads the config file during
development.

In the console, type `help` for a complete list of commands.

### Console Commands

#### System
- `help` &ndash; list all commands
- `clear` &ndash; clear console output
- `fps [limit]` &ndash; set FPS limit (0 = unlimited)
- `mem [gc]` &ndash; show memory usage
- `screenshot [file]` &ndash; take a screenshot
- `reload [audio|settings|config|all]` &ndash; reload assets
- `loglevel <level>` &ndash; set log verbosity
- `showlog` &ndash; toggle on-screen log overlay
- `profile` &ndash; toggle profiling

#### Player
- `god` &ndash; toggle god mode
- `lives <num>` &ndash; set player lives
- `powerup <type>` &ndash; grant a powerup
- `give <score|lives|bombs|shield> [amount]` &ndash; grant resources
- `info` &ndash; display player details

#### Game
- `state [name]` &ndash; switch game state
- `score <num>` &ndash; set score
- `level <num>` &ndash; jump to level
- `timescale <factor>` &ndash; adjust time scale
- `save [slot]` &ndash; save game
- `stats` &ndash; print performance statistics

#### Spawn
- `spawn <asteroid|alien|boss|powerup> [count]` &ndash; spawn entities
- `killall` &ndash; remove all enemies

#### Other
- `clear` &ndash; remove all enemies (gameplay)
- `sandbox [entity]` &ndash; show sandbox command

## Development

### Running Tests

```bash
# Install test framework
luarocks install busted

# Run all tests
busted

# Run with coverage
busted --coverage
```

### Project Structure

- `main.lua` - Main game logic and Love2D callbacks
- `CLAUDE.md` - Development guidelines and architecture notes
- `tests/` - Unit and integration tests
- Audio files (`.mp3`, `.wav`, `.ogg`, `.flac`) - Sound effects and music

## License

This project is open source. Feel free to modify and distribute as needed.

## Credits

Created by Dariyan Jones

Sound effects and music included.