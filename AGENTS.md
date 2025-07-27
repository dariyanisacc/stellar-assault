**AGENTS.md – Operating Manual for Autonomous Contributors  
Project Stellar Assault**

---

### 1. Mission & Scope
Stellar Assault is a fast‑paced, 2‑D “rogue‑lite” space shooter built with **Love2D 11.x + Lua 5.1**. Players pilot one of three unique ships through **15 sequential levels**, each ending with a bespoke boss. Difficulty scales steadily by mixing higher enemy stats, denser waves, and new attack patterns.   
This document tells every AI (or human) agent **what to build, how to build it, and the quality bar it must hit**.

---

### 2. Repository Contract

| Path | What lives here | Agent duties |
|------|-----------------|--------------|
| `src/` | Runtime code grouped by module (`core/`, `entities/`, `systems/`, `ui/`) | Respect public APIs; keep modules ≤300 LOC each. |
| `data/` | Pure JSON or Lua‑tables for **level, ship, enemy and boss specs** | Never hard‑code gameplay values; update JSON when balancing. |
| `assets/` | PNG, OGG, and spritesheets (no code) | Optimise ≤512×512 px; keep <1 MiB each. |
| `states/` | Gamestate classes (Love2D “push” pattern) | One file per state (`MenuState`, `GameState`, `PauseState`, etc.). |
| `tests/` | Busted unit/behavior tests | Provide failing test first (TDD). |
| `.github/workflows/` | CI pipeline (luacheck, busted, stylua) | Do not break green CI. |

---

### 3. Coding Standards

| Topic | Rule |
|-------|------|
| **Style** | `stylua.toml` is canonical; run `stylua .` before commits. |
| **Lint** | `luacheckrc` warnings ≥ *warning* level block PR merge. |
| **Types** | Use EmmyLua annotations for public functions to help static tooling. |
| **OOP** | Prefer composition (tables + metatables) over deep inheritance trees. |
| **Purity** | Keep render code out of update loops; deterministic update step first, then draw. |
| **Performance** | Allocate objects through the existing **object‑pool** helpers; no `table.insert` in hot loops. |
| **Commits** | Conventional Commits (`feat:`, `fix:`, `refactor:`). 1 feature = 1 PR. |

---

### 4. Gameplay Specification

#### 4.1 Ships (player‑selectable)

| Id | Role | Hull (HP) | Speed (px/s) | Fire rate (sec/shot) | Unique Ability (cooldown) |
|----|------|-----------|--------------|----------------------|---------------------------|
| `falcon` | All‑rounder | 100 | 200 | 0.30 | **Barrel Roll** – dash 0.4 s with invulnerability (6 s cd) |
| `titan`  | Tank       | 160 | 140 | 0.50 (twin guns) | **Energy Shield** – 50 % dmg reduction 3 s (8 s cd) |
| `wraith` | Glass‑cannon| 80  | 240 | 0.20 (spread 3) | **Cloak** – untargetable 1.5 s (10 s cd) |

*Agents must* keep the above numbers in `data/ships.json`. Any balance change = PR with updated unit tests.

#### 4.2 Level Timeline

| Level | Biome / Gimmick | Boss (unique mechanics) |
|-------|-----------------|--------------------------|
| 1 | Debris Field | **Alpha Drone Carrier** – spawns adds until pods destroyed |
| 2 | Ion Nebula | **Ion Serpent** – sweeping beam arcs, electrified clouds |
| 3 | Miner Belt | **Goliath Mech** – armored drills, rock chunks |
| 4 | Ice Expanse | **Frost Leviathan** – freeze breath slows player |
| 5 | Binary Outpost | **Twin War Frigates** – shared HP pool; pincer lasers |
| 6 | Quasar Rift | **Star‑Eater Kraken** – tentacle grabs, rotating shots |
| 7 | Desert Skies | **Sandstorm Colossus** – obscuring storm, homing mines |
| 8 | Plasma Forges | **Forge Behemoth** – overheats floor, molten projectiles |
| 9 | Dark‑Matter Zone | **Shadow Reaper** – teleports, mirror clones |
| 10 | Orbital Fortress | **Aegis Sentinel** – rotating shields, cannon salvo |
| 11 | Solar Flare | **Helios Phoenix** – rebirth phase, radial fire |
| 12 | Crystal Lattice | **Prism Guardian** – refracted lasers, color puzzle |
| 13 | Singularity Edge | **Void Hydra** – three heads, destroy order matters |
| 14 | Alien Armada | **Dreadnought Flagship** – multi‑turret & fighter waves |
| 15 | Proto‑Core Nexus | **The Architect** – 3 distinct phases, bullet‑hell finale |

*Level descriptors live in `data/levels/level_<n>.json`.*

#### 4.3 Difficulty Curve

```lua
-- src/core/difficulty.lua
function Difficulty.scaling(level)
  -- Exponential but capped to prevent one‑shot deaths.
  local hpMultiplier     = 1 + (level-1) * 0.25
  local damageMultiplier = 1 + (level-1) * 0.20
  local speedMultiplier  = 1 + math.min(0.02*(level-1)^1.1, 0.35)
  return hpMultiplier, damageMultiplier, speedMultiplier
end
```

*Agents modifying difficulty must add regression tests to `tests/difficulty_spec.lua`.*

---

### 5. Agent Roles & Workflow

| Role | Key Abilities | Typical Task Tickets |
|------|---------------|----------------------|
| **PlannerAgent** | Break high‑level feature into atomic subtasks; label GitHub issues | “Design boss Lv 12 pattern”, “Refactor collision system” |
| **CoderAgent** | Write Lua; follow style & unit tests; create PR | Implement new enemy, fix bug # |
| **ReviewerAgent** | Static analysis, run CI, benchmark FPS, add review comments | Approve/Request changes |
| **PlaytesterAgent** | Boot game headless with scripted inputs; attach GIF of failure | Confirm boss mechanics, check balance |
| **DocAgent** | Keep `README`, this file, and in‑code docs evergreen | Generate API docs, update diagrams |

**Lifecycle**

1. Issue created → PlannerAgent splits tasks and tags (e.g., `feat`, `balance`, `bug`).
2. CoderAgent opens branch `feat/<slug>`, pushes commits.
3. CI (`.github/workflows/ci.yml`) runs: `luacheck`, `stylua --check`, `busted`.
4. ReviewerAgent blocks merge on any ❌; when ✅ merges using **squash**.
5. PlaytesterAgent posts automated gameplay clip; flag imbalance.
6. DocAgent updates docs for any public API change.

*Never skip CI or review, even for one‑line fixes.*

---

### 6. Testing Policy

* **Unit tests**: **Busted** for pure‑logic modules (≥80 % line coverage overall).  
* **Integration**: Headless Love2D “simulation mode” (frame‑step with no window) for collision, damage, power‑up interaction.  
* **Performance**: `tests/perf_fps.lua` must keep average FPS ≥140 on CI VM (@1920×1080, release build).

---

### 7. Asset & Audio Pipeline

1. Place raw art in `assets_src/`.  
2. Run `build.sh` → compresses, trims, copies to `assets/`.  
3. Audio must be mono OGG; peak normalized to –1 dBFS.  
4. Each asset referenced only via **data files**, *not* by hard‑coded string paths.

---

### 8. Branching & Release

* `main` is always playable.  
* Milestones: **v0.1.0** (levels 1‑5), **v0.2.0** (1‑10), **v1.0.0** (all 15 + Steam‑ready).  
* Draft GitHub release notes auto‑generated from Conventional Commits.

---

### 9. Security & Safety

| Concern | Mitigation |
|---------|------------|
| Untrusted input (user profile names) | Sanitize via `string.gsub(name, "[^%w_ ]", "")`. |
| Infinite loops in AI scripts | Each enemy AI `update(dt)` capped at 0.5 ms via profiler. |
| Asset licensing | Maintain `assets/CREDITS.md`, verify CC0 or owned. |

---

### 10. Getting Started for a New (AI) Agent

```bash
git clone https://github.com/dariyanisacc/stellar-assault.git
cd stellar-assault
./build.sh        # Optimise assets
love .            # Run game in dev mode
npm install -g luacheck busted stylua  # if local tooling needed
```

1. Create a **feature branch**.  
2. Run `./scripts/new_ticket.sh "Short description"` to generate an Issue + PR template.  
3. Follow Sections 3–7 diligently.

---

### 11. Glossary

* **Entity** – Any object with position & collision (ships, bullets, power‑ups).  
* **System** – Processes a set of entities each frame (e.g., `MovementSystem`).  
* **State** – High‑level game screens (menu, playing, paused).  
* **Pool** – Pre‑allocated table of reusable entities.

---

### 12. Change‑log Rules

*Update this file whenever mechanics or workflow expectations change.  
Each modification should mention the **commit hash** that introduced it.*

---

Happy coding. Keep the stars bright and the pull requests even brighter! 🚀
