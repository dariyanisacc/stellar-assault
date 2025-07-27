-- Lint only our own source; ignore vendored LuaRocks tree and its tests
exclude_files = {
  "./.luarocks/**"
}

std = "lua51+love"

globals = {
  -- project-wide globals
  "Class",
  "Game",
  "stateManager",
  "debugConsole",
  "debugOverlay",
  "CONFIG",
  -- game state globals
  "Collision",
  "activePowerups",
  "alienLasers",
  "aliens",
  "applyFontScale",
  "applyPalette",
  "asteroids",
  "availableShips",
  "backgroundMusic",
  "boss",
  "boss2Sprite",
  "bossMusic",
  "bossSpawned",
  "bossSprite",
  "bossSprites",
  "currentLevel",
  "currentSaveSlot",
  "debugMode",
  "drawDebugInfo",
  "drawDebugOverlay",
  "drawStarfield",
  "enemyShips",
  "enemiesDefeated",
  "explosionSound",
  "explosions",
  "frameTimeHistory",
  "gameComplete",
  "gameOverSound",
  "gameState",
  "height",
  "initStarfield",
  "initStates",
  "initWindow",
  "invulnerableTime",
  "laserSound",
  "lasers",
  "levelAtDeath",
  "levelComplete",
  "lives",
  "loadAudioResources",
  "loadFonts",
  "masterVolume",
  "maxFrameTimeHistory",
  "mediumFont",
  "menuConfirmSound",
  "menuFont",
  "menuSelectSound",
  "missiles",
  "musicVolume",
  "playPositionalSound",
  "player",
  "playerShips",
  "powerupSound",
  "powerupTexts",
  "powerups",
  "saveSettings",
  "score",
  "selectedShip",
  "sfxVolume",
  "shieldBreakSound",
  "smallFont",
  "soundMaxDistance",
  "soundReferenceDistance",
  "spriteScale",
  "uiFont",
  "uiManager",
  "updateAudioVolumes",
  "updateStarfield",
  "utf8",
  "victorySound"
}

read_globals = {
  "love",
  -- busted testing globals
  "describe",
  "it",
  "before_each"
}

ignore = {
  "111", "112", "122", "143", "241", "412", "421", "431", "542",
  "611", "612", "614"
}

unused_args = false
max_line_length = 120
