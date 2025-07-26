-- src/collision.lua
-- Minimal, dependency‑free collision helpers for Stellar Assault
-- Author: Ada (ChatGPT) • 2025‑07‑25
--
-- Design goals:
--   • Stateless – just pure functions.
--   • Cover the handful of primitives most arcade shooters need.
--   • Objects can either pass raw numbers or implement :getBounds().
---------------------------------------------------------------------

local Collision = {}

---------------------------------------------------------------------
-- Axes‑aligned bounding‑box (AABB) helpers --------------------------
---------------------------------------------------------------------

--- Return *true* if rectangles A and B overlap (inclusive).
-- @param ax, ay      top‑left of rect A
-- @param aw, ah      width, height of rect A
-- @param bx, by      top‑left of rect B
-- @param bw, bh      width, height of rect B
function Collision.aabb(ax, ay, aw, ah, bx, by, bw, bh)
  return ax < bx + bw and bx < ax + aw and ay < by + bh and by < ay + ah
end

--- Convenience wrapper: takes two tables where each has x, y, w, h fields
function Collision.aabbTables(a, b)
  return Collision.aabb(a.x, a.y, a.w or a.width, a.h or a.height,
                        b.x, b.y, b.w or b.width, b.h or b.height)
end

--- Polymorphic version: objects supply :getBounds() → x, y, w, h
function Collision.aabbObjects(a, b)
  local ax, ay, aw, ah = a:getBounds()
  local bx, by, bw, bh = b:getBounds()
  return Collision.aabb(ax, ay, aw, ah, bx, by, bw, bh)
end

---------------------------------------------------------------------
-- Circle / radius checks -------------------------------------------
---------------------------------------------------------------------

--- Return *true* if distance between centres ≤ sum of radii.
function Collision.circles(ax, ay, ar, bx, by, br)
  local dx, dy = ax - bx, ay - by
  local r = ar + br
  return (dx * dx + dy * dy) <= (r * r)
end

--- Convenience: tables with x, y, r fields.
function Collision.circlesTables(a, b)
  return Collision.circles(a.x, a.y, a.r or a.radius,
                           b.x, b.y, b.r or b.radius)
end

---------------------------------------------------------------------
-- Point helpers -----------------------------------------------------
---------------------------------------------------------------------

function Collision.pointInRect(px, py, rx, ry, rw, rh)
  return px >= rx and px <= rx + rw and py >= ry and py <= ry + rh
end

function Collision.pointInCircle(px, py, cx, cy, r)
  local dx, dy = px - cx, py - cy
  return dx * dx + dy * dy <= r * r
end

---------------------------------------------------------------------
-- Swept AABB (for simple continuous collision) ----------------------
---------------------------------------------------------------------
-- Returns: tFirst, tLast in [0,1] of collision interval (or nil if none)
-- Based on "Dynamic rectangle - rectangle intersection" by Casey Muratori
function Collision.sweptAABB(ax, ay, aw, ah, avx, avy, bx, by, bw, bh)
  -- Expand static box by moving one
  local expandedX = bx - aw
  local expandedY = by - ah
  local expandedW = bw + aw
  local expandedH = bh + ah

  -- Ray‑cast entry/exit times along each axis
  local invVx = avx ~= 0 and 1 / avx or 0
  local invVy = avy ~= 0 and 1 / avy or 0

  local tx1 = (expandedX - ax) * invVx
  local tx2 = (expandedX + expandedW - ax) * invVx
  local ty1 = (expandedY - ay) * invVy
  local ty2 = (expandedY + expandedH - ay) * invVy

  local tEntry = math.max(math.min(tx1, tx2), math.min(ty1, ty2))
  local tExit  = math.min(math.max(tx1, tx2), math.max(ty1, ty2))

  if tEntry > tExit or tExit < 0 or tEntry > 1 then
    return nil -- no collision within 0..1
  end
  return math.max(0, tEntry), math.min(1, tExit)
end

---------------------------------------------------------------------
return Collision
