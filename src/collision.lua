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
  return Collision.aabb(
    a.x,
    a.y,
    a.w or a.width,
    a.h or a.height,
    b.x,
    b.y,
    b.w or b.width,
    b.h or b.height
  )
end

Collision.checkAABB = Collision.aabbTables

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
  return Collision.circles(a.x, a.y, a.r or a.radius, b.x, b.y, b.r or b.radius)
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

-- Compatibility helper for legacy code
Collision.checkAABB = Collision.aabbTables

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
  local tExit = math.min(math.max(tx1, tx2), math.max(ty1, ty2))

  if tEntry > tExit or tExit < 0 or tEntry > 1 then
    return nil -- no collision within 0..1
  end
  return math.max(0, tEntry), math.min(1, tExit)
end

---------------------------------------------------------------------
-- Oriented rectangle overlap (SAT) ---------------------------------
---------------------------------------------------------------------
-- Checks two rectangles with center x,y, size w,h and rotation (radians)
-- using a Separating Axis Test on the 4 unique axes.
--- Return true if two oriented rectangles overlap (center-based)
-- @param ax, ay, aw, ah, arot  first rect center, size and rotation
-- @param bx, by, bw, bh, brot  second rect center, size and rotation
function Collision.obb(ax, ay, aw, ah, arot, bx, by, bw, bh, brot)
  local ahw, ahh = aw * 0.5, ah * 0.5
  local bhw, bhh = bw * 0.5, bh * 0.5

  local acr, asr = math.cos(arot), math.sin(arot)
  local bcr, bsr = math.cos(brot), math.sin(brot)

  -- Oriented axes in world space
  local axx, axy = acr, asr
  local ayx, ayy = -asr, acr
  local bxx, bxy = bcr, bsr
  local byx, byy = -bsr, bcr

  -- Vector between centers
  local dx, dy = bx - ax, by - ay

  -- Test 4 axes: A.x, A.y, B.x, B.y
  -- Helper to test a single axis
  local function separatedOn(lx, ly)
    local dist = math.abs(dx * lx + dy * ly)
    -- Projection radii for each box against axis (lx, ly)
    local ra = math.abs(lx * axx + ly * axy) * ahw + math.abs(lx * ayx + ly * ayy) * ahh
    local rb = math.abs(lx * bxx + ly * bxy) * bhw + math.abs(lx * byx + ly * byy) * bhh
    return dist > (ra + rb)
  end

  if separatedOn(axx, axy) then return false end
  if separatedOn(ayx, ayy) then return false end
  if separatedOn(bxx, bxy) then return false end
  if separatedOn(byx, byy) then return false end
  return true
end

--- Convenience wrapper using tables with x,y,width,height,rotation (radians)
function Collision.obbTables(a, b)
  local acx = a.cx or (a.x + (a.width or a.w) * 0.5)
  local acy = a.cy or (a.y + (a.height or a.h) * 0.5)
  local bcx = b.cx or (b.x + (b.width or b.w) * 0.5)
  local bcy = b.cy or (b.y + (b.height or b.h) * 0.5)
  local aw, ah = a.width or a.w, a.height or a.h
  local bw, bh = b.width or b.w, b.height or b.h
  local ar, br = a.rotation or 0, b.rotation or 0
  return Collision.obb(acx, acy, aw, ah, ar, bcx, bcy, bw, bh, br)
end

---------------------------------------------------------------------
return Collision
