-- FERRY.lua — Teleport A<->B with dwell + cooldown + route resume
-- Works with GROUND.lua storing:
--   STATE.ROUTES[groupName]      -> full planned route (points = {...})
--   STATE.FERRY_CHAINS[groupName] -> { {A=zoneA, B=zoneB, aName="...", bName="..."}, ... }
--
-- Behavior:
--   • Group must dwell in "FERRY_*_A/B" zone for DWELL_SEC (default 30s)
--   • Teleport to the opposite pier if pair cooldown expired (default 20 min)
--   • Resume its saved route AFTER the destination pier
--   • Cooldown is tracked per pier pair (so opposite direction shares it)

FERRY = FERRY or {}

---------------------------------------------------------------------
-- Config / state
---------------------------------------------------------------------
FERRY.cfg = {
  dwell_sec     = (CONFIG and CONFIG.GROUND and CONFIG.GROUND.FERRY_DWELL_SEC) or 30,   -- time to wait at pier
  cooldown_sec  = (CONFIG and CONFIG.GROUND and CONFIG.GROUND.FERRY_COOLDOWN_SEC) or 1200, -- 20 min
  debug         = (CONFIG and CONFIG.FERRY and CONFIG.FERRY.debug) or false,
}

local function dbg(msg) if FERRY.cfg.debug then trigger.action.outText("[FERRY] "..tostring(msg), 6) end end
local function now() return timer.getTime() end

-- pair cooldowns "A|B" => t_expires
FERRY._cooldowns = FERRY._cooldowns or {}
-- tracked ground groups by name
FERRY._tracked   = FERRY._tracked   or {}
-- dwell timers per group per pair: dwellStart[groupName][pairKey] = t_started
FERRY._dwellStart= FERRY._dwellStart or {}
FERRY._armed     = FERRY._armed or false

---------------------------------------------------------------------
-- Utils
---------------------------------------------------------------------
local function normPairKey(aName,bName)
  if not aName or not bName then return nil end
  if aName < bName then return aName.."|"..bName else return bName.."|"..aName end
end

local function getZone(name)
  if not name then return nil end
  local z = trigger.misc.getZone(name)
  if z and z.point then return { name=name, x=z.point.x, y=0, z=z.point.z, r=z.radius or 120 } end
  return nil
end

local function unitPoint(grp)
  if not grp or not grp.isExist or not grp:isExist() then return nil end
  local u = grp:getUnit(1); if not (u and u.isExist and u:isExist()) then return nil end
  local p = u:getPoint(); return { x=p.x, y=p.y, z=p.z }
end

local function inZone(pt, z)
  local dx, dz = pt.x - z.x, pt.z - z.z
  return (dx*dx + dz*dz) <= (z.r * z.r)
end

local function groupSideStr(grp)
  local s = grp:getCoalition()
  return (s==coalition.side.RED) and "RED" or "BLUE"
end

-- Simple route assign (fallback if GROUND.assignRoute not present)
local function assignRoute(group, points)
  if not group or not group:isExist() or not points or #points==0 then return end
  local route = { points = points }
  local ctrl = group:getController()
  if ctrl then pcall(function() ctrl:setTask({ id='Mission', params={ route=route } }) end) end
end

local function wp(x, z, onRoad, speed)
  return { x=x, y=z, action=onRoad and "On Road" or "Off Road", speed=speed or 6.0, speed_locked=true, type="Turning Point", ETA=0, ETA_locked=false }
end

-- Resume saved route AFTER a pier (pick nearest saved point to pier and continue after it)
local function routeAfterPier(saved, pierZone)
  if not saved or not saved.points or not pierZone then return nil end
  local pts = saved.points
  local bestI, bestD2 = nil, 1e18
  for i,p in ipairs(pts) do
    local dx, dz = (p.x - pierZone.x), (p.y - pierZone.z); local d2 = dx*dx + dz*dz
    if d2 < bestD2 then bestD2, bestI = d2, i end
  end
  local start = (bestI or 1) + 1
  local out = {}
  for i=start, #pts do out[#out+1] = pts[i] end
  if #out==0 then out[#out+1] = wp(pierZone.x + 80, pierZone.z + 80, true, 6.0) end
  return out
end

-- Copy old group's unit types/skills, spawn at destination pier (small lateral spread)
local function respawnAtPier(oldGroup, dstZone)
  if not oldGroup or not oldGroup:isExist() or not dstZone then return nil end
  local oldName = oldGroup:getName()
  local sideStr = groupSideStr(oldGroup)
  local countryId = (CONFIG and CONFIG.GROUND and CONFIG.GROUND.COUNTRY and CONFIG.GROUND.COUNTRY[sideStr])
                    or ((sideStr=="RED") and country.id.RUSSIA or country.id.USA)

  local seed = math.random(100000, 999999)
  local newName = oldName.."_F"..seed

  local units = oldGroup:getUnits() or {}
  local data = { visible=false, lateActivation=false, task="Ground Nothing", route={ points = {} }, units={}, name=newName }
  local lateral = 6
  for i,u in ipairs(units) do
    if u and u.isExist and u:isExist() then
      local tp = u:getTypeName() or "Soldier M4"
      data.units[#data.units+1] = { name=newName.."_U"..i, type=tp, skill="Average", x=dstZone.x + (i-1)*lateral, y=dstZone.z + (i-1)*lateral, heading=0 }
    end
  end
  data.route.points = { wp(dstZone.x + 30, dstZone.z + 30, true, 6.0) }

  local newGroup = coalition.addGroup(countryId, Group.Category.GROUND, data)
  if not newGroup then return nil end

  -- Move STATE mappings to the new group name
  STATE = STATE or {}; STATE.ROUTES = STATE.ROUTES or {}; STATE.FERRY_CHAINS = STATE.FERRY_CHAINS or {}
  if STATE.ROUTES[oldName]      then STATE.ROUTES[newName]      = STATE.ROUTES[oldName];      STATE.ROUTES[oldName]      = nil end
  if STATE.FERRY_CHAINS[oldName] then STATE.FERRY_CHAINS[newName] = STATE.FERRY_CHAINS[oldName]; STATE.FERRY_CHAINS[oldName] = nil end

  pcall(function() oldGroup:destroy() end)
  return newGroup, newName
end

---------------------------------------------------------------------
-- Teleport core
---------------------------------------------------------------------
local function teleportIfReady(grp, pierA, pierB)
  if not grp or not grp:isExist() then return false end
  local pos = unitPoint(grp); if not pos then return false end

  local atA, atB = inZone(pos, pierA), inZone(pos, pierB)
  if not atA and not atB then return false end

  local pairKey = normPairKey(pierA.name, pierB.name)
  local cd = FERRY._cooldowns[pairKey] or 0
  if now() < cd then
    dbg(string.format("%s ferry %s cooling down (%ds)", grp:getName(), pairKey, math.floor(cd - now())))
    return false
  end

  -- dwell requirement
  FERRY._dwellStart[grp:getName()] = FERRY._dwellStart[grp:getName()] or {}
  local dTbl = FERRY._dwellStart[grp:getName()]
  local started = dTbl[pairKey]
  if not started then
    dTbl[pairKey] = now()
    dbg(string.format("%s started dwell at %s", grp:getName(), atA and pierA.name or pierB.name))
    return false
  end
  if now() - started < (FERRY.cfg.dwell_sec or 30) then
    return false
  end

  -- choose destination
  local dst = atA and pierB or pierA
  dbg(string.format("Teleporting %s from %s to %s", grp:getName(), atA and pierA.name or pierB.name, dst.name))

  local newG, newName = respawnAtPier(grp, dst)
  if not newG then return false end

  -- resume route after the destination pier
  local saved = STATE and STATE.ROUTES and STATE.ROUTES[newName]
  local resume = routeAfterPier(saved, dst)
  if resume and #resume>0 then
    if GROUND and GROUND.assignRoute then pcall(function() GROUND.assignRoute(newG, resume) end)
    else assignRoute(newG, resume) end
  end

  -- cooldown + reset dwell
  FERRY._cooldowns[pairKey] = now() + (FERRY.cfg.cooldown_sec or 1200)
  FERRY._dwellStart[newName] = FERRY._dwellStart[grp:getName()] or {}
  FERRY._dwellStart[grp:getName()] = nil

  -- keep tracking
  FERRY._tracked[newName] = true
  FERRY._tracked[grp:getName()] = nil
  return true
end

---------------------------------------------------------------------
-- Scanner
---------------------------------------------------------------------
local function tick()
  -- copy names to avoid mutation during iteration
  local names = {}
  for gName,_ in pairs(FERRY._tracked) do names[#names+1] = gName end

  for _,name in ipairs(names) do
    local g = Group.getByName(name)
    if not (g and g:isExist()) then
      FERRY._tracked[name] = nil
    else
      local chain = STATE and STATE.FERRY_CHAINS and STATE.FERRY_CHAINS[name]
      if chain and #chain>0 then
        for _,seg in ipairs(chain) do
          local A = seg.A or getZone(seg.aName or seg[1])
          local B = seg.B or getZone(seg.bName or seg[2])
          if A and B then
            seg.A, seg.B = A, B
            if teleportIfReady(g, A, B) then break end   -- only one hop per tick
          end
        end
      end
    end
  end
  return now() + 3.0
end

---------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------
function FERRY.init()
  if FERRY._armed then return end
  FERRY._armed = true
  timer.scheduleFunction(function() return tick() end, {}, now()+3.0)
  dbg(string.format("FERRY initialized (dwell=%ds, cooldown=%ds).", FERRY.cfg.dwell_sec, FERRY.cfg.cooldown_sec))
end

-- Call right after a group is spawned/routed by GROUND.lua
function FERRY.track(groupOrName)
  local name = type(groupOrName)=="string" and groupOrName or (groupOrName and groupOrName.getName and groupOrName:getName())
  if not name then return end
  FERRY._tracked[name] = true
  dbg("Tracking "..name)
end

function FERRY.setDebug(on) FERRY.cfg.debug = not not on end

pcall(function() trigger.action.outText("FERRY.lua LOADED...).", 5) end)
return FERRY
