# Development Guidelines

This document describes coding conventions and architectural notes for Stellar Assault.

## Coding Style

- Format Lua files with **stylua** using the repo's `stylua.toml` configuration.
- Lint with **luacheck**; see `.luacheckrc` for globals and rules.

## Testing

- Use **busted** to run the test suite: `busted`.
- Generate coverage reports with `busted --coverage`.

## Architecture Notes

- Game states live under `states/` and are managed by `src/StateManager.lua`.
- Core game logic resides in `src/` modules.
- `src/objectpool.lua` implements reusable pools for trails, debris and other entities.

For a deeper overview of the modular structure, see `REFACTORING_GUIDE.md`.
