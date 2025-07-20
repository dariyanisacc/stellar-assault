# SpaceDodger Test Suite

This directory contains the test suite for the SpaceDodger game.

## Structure

- `unit/` - Unit tests for individual functions and components
- `integration/` - Integration tests for game systems
- `mocks/` - Mock objects and frameworks for testing

## Running Tests

### Prerequisites

Install the busted testing framework:
```bash
luarocks install busted
```

For code coverage (optional):
```bash
luarocks install luacov
```

### Running All Tests

From the SpaceDodger root directory:
```bash
busted
```

Or using the test runner:
```bash
./run_tests.lua
```

### Running Specific Test Categories

Run only unit tests:
```bash
busted -t unit
```

Run only integration tests:
```bash
busted -t integration
```

### Running Individual Test Files

```bash
busted tests/unit/collision_test.lua
```

## Test Coverage

To run tests with code coverage:
```bash
busted --coverage
```

Then generate the coverage report:
```bash
luacov
```

View the coverage report in `luacov.report.out`.

## Writing Tests

Tests use the busted framework with BDD-style syntax:

```lua
describe("Feature Name", function()
    before_each(function()
        -- Setup code
    end)
    
    it("should do something", function()
        assert.equals(expected, actual)
    end)
end)
```

## Current Test Coverage

### Unit Tests
- ✅ Collision Detection (`collision_test.lua`)
- ✅ Game State Management (`gamestate_test.lua`)
- ✅ Player Mechanics (`player_test.lua`)
- ✅ Enemy Spawning and Behavior (`wavemanager_test.lua`)
- ✅ Powerup System (`powerup_test.lua`)
- ✅ Scoring System (`score_test.lua`)

### Integration Tests
- ✅ Full game flow (`game_loop_test.lua`)
- ✅ Level progression (`level_progression_test.lua`)
- 🔲 Boss battles

## Mock Framework

The test suite includes a mock Love2D framework (`love_mock.lua`) that simulates the Love2D API for testing game logic without requiring a graphical environment.