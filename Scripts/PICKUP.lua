-- PICKUP.lua — Helicopter pickup/deploy system (replaces FOB.lua)
-- Spec:
--  * Every OWNED airfield zone is a pickup zone for that side’s helicopters.
--  * Allowed helos & capacities (from ToDo):
--      UH-1H, Mi-24P: up to 2 infantry squads, no vehicle
--      CH-47D / CH-47Fbl1 / Mi-8MT: (EITHER mode) up to 4 squads OR 2 squads + 1 vehicle
--  * Squad composition:
--      BLUE: 4x "Soldier M4" + 1x "Soldier M249"
--      RED:  4x "Paratrooper AKS-74" + 1x "Paratrooper RPG-16"
--  * Drop inside enemy AF zone -> ROE OPEN FIRE + move/attack AF.
--  * Drop elsewhere -> make groups player-drivable (CA) and set guard/engage behavior.
--  * Economy: costs are debited from the pickup airfield (STATE helpers). Falls back to CONFIG.PICKUP.COST if UNITS has no per-unit cost.
--  * Idle-despawn: start watching after ~10 min idle, despawn at 30 min idle (configurable).
--  * Auto-attach “PICKUP” F10 menu to player/client helicopters on birth.

PICKUP = PICKUP or {}

---------------------------------------------------------------------
-- Config / constants (overridable via CONFIG.PICKUP)
---------------------------------------------------------------------
PICKUP.cfg = {
  -- toggle from CONFIG.PICKUP.debug (bool)
  debug = (CONFIG and CONFIG.PICKUP and CONFIG.PICKUP.debug) or false,

  -- Costs fallback if UNITS.lua doesn’t expose per-type costs:
  COST = (CONFIG and CONFIG.PICKUP and CONFIG.PICKUP.COST) or {
    INF_SQUAD = { mp=35, ammo=0,  fuel=0  },  -- per squad
    VEHICLE   = { mp=120, ammo=40, fuel=25 }, -- per vehicle (if unit type has no explicit cost)
  },

  -- Default vehicle types if UNITS.lua doesn’t provide them; can override in CONFIG.PICKUP.VEHICLE_TYPES
  VEHICLE_TYPES = (CONFIG and CONFIG.PICKUP and CONFIG.PICKUP.VEHICLE_TYPES) or {
    BLUE = { "M-113", "M-60", "L118_Unit" },
    RED  = { "BRDM-2", "BMP-2", "M2A1_105" },
  },

  -- Idle logic
  IDLE_GRACE_SEC   = (CONFIG and CONFIG.PICKUP and CONFIG.PICKUP.IDLE_GRACE_SEC)   or 600,   -- start counting idleness after 10 min
  IDLE_DESPAWN_SEC = (CONFIG and CONFIG.PICKUP and CONFIG.PICKUP.IDLE_DESPAWN_SEC) or 1800,  -- despawn after 30 min idle
  MOVE_CHECK_SEC   = (CONFIG and CONFIG.PICKUP and CONFIG.PICKUP.MOVE_CHECK_SEC)   or 30,    -- poll interval
}

local function dbg(t) if PICKUP.cfg.debug then trigger.action.outText("[PICKUP] "..tostring(t), 6) end end
local function say(t, d) trigger.action.outText("[PICKUP] "..tostring(t), d or 5) end
local function now() return timer.getTime() end

---------------------------------------------------------------------
-- Allowed helicopters & capacity rules
---------------------------------------------------------------------
local ALLOWED = {
  ["UH-1H"]     = { maxSquads = 2, maxVehicle = 0 },
  ["Mi-24P"]    = { maxSquads = 2, maxVehicle = 0 },
  ["Mi-8MT"]    = { maxSquads = 4, maxVehicle = 1, mode="EITHER" }, -- 2 squads + 1 vehicle OR up to 4 squads
  ["CH-47D"]    = { maxSquads = 4, maxVehicle = 1, mode="EITHER" },
  ["CH-47Fbl1"] = { maxSquads = 4, maxVehicle = 1, mode="EITHER" }, -- ED type name
}

-- Squad templates
local SQUAD = {
  BLUE = { "Soldier M4", "Soldier M4", "Soldier M4", "Soldier M4", "Soldier M249" },
  RED  = { "Paratrooper AKS-74", "Paratrooper AKS-74", "Paratrooper AKS-74", "Paratrooper AKS-74", "Paratrooper RPG-16" },
}

---------------------------------------------------------------------
-- Helpers: TERRAIN zones, ownership, geometry
---------------------------------------------------------------------
local function getZone(name)
  if not name then return nil end
  local z = trigger.misc.getZone(name)
  if z and z.point then return { name=name, x=z.point.x, y=0, z=z.point.z, r=z.radius or 1200 } end
  return nil
end

local function sideStrFromCoal(coal) return (coal==coalition.side.RED) and "RED" or "BLUE" end
local function ownerStr(af)
  if TERRAIN and TERRAIN.getOwner then
    local o = TERRAIN.getOwner(af)
    if o=="BLUE" or o==coalition.side.BLUE or o==2 then return "BLUE" end
    if o=="RED"  or o==coalition.side.RED  or o==1 then return "RED"  end
  end
  return nil
end

local function dist2(a,b) local dx=a.x-b.x; local dz=a.z-b.z; return math.sqrt(dx*dx+dz*dz) end
local function inZone(pt, z) if not (pt and z) then return false end return dist2(pt, {x=z.x, z=z.z}) <= (z.r or 0) end

local function heloLanded(u)
  if not u or not u:isExist() then return false end
  if u.inAir and u:inAir() then return false end
  local v = u:getVelocity(); local sp = math.sqrt(v.x*v.x + v.y*v.y + v.z*v.z)
  return sp < 1.8
end

local function heloTypeAllowed(t) return ALLOWED[t] ~= nil end

local function airfieldZoneAndNameForPoint(pt, sideStr)
  if not (TERRAIN and TERRAIN.AIRFIELDS) then return nil,nil end
  for af,e in pairs(TERRAIN.AIRFIELDS) do
    local z = getZone(e.zone or af)
    if z and inZone(pt, z) then
      if not sideStr or ownerStr(af) == sideStr then
        return z, af
      else
        return nil, af -- inside an AF zone but not owned by side
      end
    end
  end
  return nil,nil
end

---------------------------------------------------------------------
-- Economy adapters (STATE.* or STATE.econ.*)
---------------------------------------------------------------------
local function econ_can(af, side, cost)
  if not cost then return true end
  if STATE and STATE.canAfford then return STATE.canAfford(af, side, cost) end
  if STATE and STATE.econ and STATE.econ.canAfford then return STATE.econ.canAfford(af, side, cost) end
  return true
end

local function econ_debit(af, side, cost)
  if not cost then return true end
  if STATE and STATE.debit then return STATE.debit(af, side, cost) end
  if STATE and STATE.econ and STATE.econ.debit then return STATE.econ.debit(af, side, cost) end
  return true
end

-- Per-unit cost via UNITS.lua if available; else fallback to PICKUP.cfg.COST
local function unitCostOrFallback(unitType, kind)
  if UNITS and UNITS.costFor then
    local c = UNITS.costFor(unitType)
    if c then return c end
  end
  if UNITS and UNITS.COST and UNITS.COST[unitType] then
    return UNITS.COST[unitType]
  end
  if kind == "SQUAD" then return PICKUP.cfg.COST.INF_SQUAD end
  return PICKUP.cfg.COST.VEHICLE
end

---------------------------------------------------------------------
-- Spawn helpers (infantry squad / vehicle)
---------------------------------------------------------------------
local function countryFor(side)
  if CONFIG and CONFIG.GROUND and CONFIG.GROUND.COUNTRY and CONFIG.GROUND.COUNTRY[side] then
    return CONFIG.GROUND.COUNTRY[side]
  end
  return (side=="RED") and country.id.RUSSIA or country.id.USA
end

local function jitter(pt, rmin, rmax)
  local ang = math.random() * math.pi * 2
  local rad = (rmin or 5) + math.random() * ((rmax or 25) - (rmin or 5))
  return { x = pt.x + math.cos(ang)*rad, y = 0, z = pt.z + math.sin(ang)*rad }
end

local function spawnInfantrySquad(side, atPoint, baseName, playerDrive)
  local ctry = countryFor(side)
  local types = SQUAD[side]
  local gname = string.format("PICKUP_%s_Inf_%06d", side, math.random(999999))
  local units = {}
  for i,t in ipairs(types) do
    local p = jitter(atPoint, 2, 6)
    units[#units+1] = {
      name = gname.."_"..i, type = t, x = p.x, y = p.z, heading = 0,
      skill = "Good", playerCanDrive = (playerDrive and true or false),
    }
  end
  local grp = {
    visible=false, lateActivation=false, tasks={}, task="Ground Nothing",
    route={ points = {{ x=atPoint.x, y=atPoint.z, type="Turning Point", action="Off Road", speed=5 }} },
    units=units, name=gname,
    category = Group.Category.GROUND,
  }
  local ok, g = pcall(function() return coalition.addGroup(ctry, Group.Category.GROUND, grp) end)
  return ok and g or nil, gname
end

local function pickVehicleType(side)
  -- Prefer CONFIG.PICKUP.VEHICLE_TYPES; else try UNITS.GROUND tables; else nil
  local list = PICKUP.cfg.VEHICLE_TYPES[side]
  if list and #list > 0 then return list[math.random(#list)] end

  if UNITS and UNITS.GROUND and UNITS.GROUND[side] then
    local u = UNITS.GROUND[side]
    local candidates = u.VEHICLE or u.TRUCK or u.APC or u.TANK
    if candidates and #candidates > 0 then return candidates[math.random(#candidates)] end
  end
  return nil
end

local function spawnVehicle(side, atPoint, baseName, playerDrive, specificType)
  local ctry = countryFor(side)
  local unitType = specificType or pickVehicleType(side)
  if not unitType then return nil, nil, "no-veh-type" end

  local p = jitter(atPoint, 3, 7)
  local gname = string.format("PICKUP_%s_Veh_%06d", side, math.random(999999))
  local grp = {
    visible=false, lateActivation=false, tasks={}, task="Ground Nothing",
    route={ points = {{ x=p.x, y=p.z, type="Turning Point", action="Off Road", speed=6 }} },
    units={
      { name=gname.."_1", type=unitType, x=p.x, y=p.z, heading=0, skill="Average",
        playerCanDrive = (playerDrive and true or false) }
    },
    name=gname, category=Group.Category.GROUND
  }
  local ok, g = pcall(function() return coalition.addGroup(ctry, Group.Category.GROUND, grp) end)
  return ok and g or nil, gname, unitType
end

---------------------------------------------------------------------
-- Post-deploy behavior (attack AF / guard here) + idle-despawn tracker
---------------------------------------------------------------------
local _spawnTrack = {}  -- gName -> { t0=, lastActive=, lastPos= }

local function setGroundROE(ctrl)
  if not ctrl then return end
  if AI and AI.Option and AI.Option.Ground and AI.Option.Ground.id and AI.Option.Ground.val then
    local id  = AI.Option.Ground.id
    local val = AI.Option.Ground.val
    pcall(function()
      if id.ROE and val.ROE and val.ROE.OPEN_FIRE then ctrl:setOption(id.ROE, val.ROE.OPEN_FIRE) end
      if id.ALARM_STATE and val.ALARM_STATE and val.ALARM_STATE.RED then ctrl:setOption(id.ALARM_STATE, val.ALARM_STATE.RED) end
    end)
  else
    -- fallback via Air options if Ground not present in the running environment
    if AI and AI.Option and AI.Option.Air and AI.Option.Air.id and AI.Option.Air.val then
      local id  = AI.Option.Air.id
      local val = AI.Option.Air.val
      pcall(function() if id.ROE and val.ROE and val.ROE.OPEN_FIRE then ctrl:setOption(id.ROE, val.ROE.OPEN_FIRE) end end)
    end
  end
end

local function taskSearchAndEngage(group, center, radius)
  if not (group and group:isExist()) then return end
  local ctrl = group:getController()
  if not ctrl then return end
  setGroundROE(ctrl)
  pcall(function()
    ctrl:setTask({
      id='EngageTargetsInZone',
      params = { targetTypes={"All"}, x = center.x, y = center.z, zoneRadius = radius or 800, priority = 1 }
    })
  end)
end

local function orderMove(group, pt)
  if not (group and group:isExist()) then return end
  local ctrl = group:getController(); if not ctrl then return end
  local route = { points = { { x=pt.x, y=pt.z, action="Off Road", type="Turning Point", speed=6, speed_locked=true, ETA=0, ETA_locked=false } } }
  pcall(function() ctrl:setTask({ id='Mission', params={ route=route } }) end)
end

local function beginIdleWatch(g)
  if not (g and g:isExist()) then return end
  local name = g:getName()
  local u = g:getUnit(1); if not u then return end
  local p = u:getPoint()
  _spawnTrack[name] = { t0 = now(), lastActive = now(), lastPos = {x=p.x, z=p.z} }
end

local function movedEnough(a, b) local dx=a.x-b.x; local dz=a.z-b.z; return (dx*dx + dz*dz) > (30*30) end

local function pollIdle()
  for n, rec in pairs(_spawnTrack) do
    local g = Group.getByName(n)
    if g and g:isExist() then
      local u = g:getUnit(1)
      if u and u:isExist() then
        local p = u:getPoint(); local pos = {x=p.x, z=p.z}
        if movedEnough(pos, rec.lastPos) then rec.lastActive = now(); rec.lastPos = pos end
        local idleFor = now() - rec.lastActive
        if idleFor >= PICKUP.cfg.IDLE_DESPAWN_SEC then
          pcall(function() g:destroy() end)
          say("Despawned idle ground group: "..n, 6)
          _spawnTrack[n] = nil
        elseif idleFor >= PICKUP.cfg.IDLE_GRACE_SEC and math.floor(idleFor) % 300 < PICKUP.cfg.MOVE_CHECK_SEC then
          -- gentle periodic reminder after grace
          dbg(string.format("Idle %s for %.0f sec (will despawn at %ds)", n, idleFor, PICKUP.cfg.IDLE_DESPAWN_SEC))
        end
      end
    else
      _spawnTrack[n] = nil
    end
  end
  return now() + PICKUP.cfg.MOVE_CHECK_SEC
end

-- Event: any shot from a tracked group resets idle timer
world.addEventHandler({
  onEvent = function(e)
    if not e or not e.id then return end
    if e.id == world.event.S_EVENT_SHOT and e.initiator then
      local g = e.initiator.getGroup and e.initiator:getGroup() or nil
      if g and g.getName then
        local n = g:getName()
        if _spawnTrack[n] then _spawnTrack[n].lastActive = now() end
      end
    end
  end
})

---------------------------------------------------------------------
-- Cargo bookkeeping per helo group
---------------------------------------------------------------------
PICKUP._cargo = PICKUP._cargo or {} -- [groupName] = { squads=0, veh=false, vehType=nil, modeLock=nil, fromAF=nil }

local function cargoFor(gName) PICKUP._cargo[gName] = PICKUP._cargo[gName] or { squads=0, veh=false } return PICKUP._cargo[gName] end
local function resetCargo(gName) PICKUP._cargo[gName] = { squads=0, veh=false, vehType=nil, modeLock=nil, fromAF=nil } end

---------------------------------------------------------------------
-- Menu wiring per helo client
---------------------------------------------------------------------
local function groupFromUnit(u) if not u then return nil end return u:getGroup() end

local function buildMenusForGroup(g)
  if not (g and g:isExist()) then return end
  local gid = g:getID()
  missionCommands.removeItemForGroup(gid, nil)
  local root = missionCommands.addSubMenuForGroup(gid, "PICKUP")

  missionCommands.addCommandForGroup(gid, "Load Infantry Squad", root, function()
    local u = g:getUnit(1); if not u then return end
    local t = u:getTypeName(); if not heloTypeAllowed(t) then say("This helicopter is not allowed to pickup.",6); return end
    if not heloLanded(u) then say("Land and stop inside an OWNED airfield zone to load.", 6); return end

    local side = sideStrFromCoal(u:getCoalition())
    local p = u:getPoint(); local pt = {x=p.x, z=p.z}
    local z, af = airfieldZoneAndNameForPoint(pt, side)
    if not z or not af then say("Not inside an OWNED airfield zone.", 6); return end

    local cap = ALLOWED[t]
    local cg = cargoFor(g:getName())

    -- Enforce EITHER mode for heavy lifters if a vehicle is (or will be) present
    if cap.mode=="EITHER" and cg.veh and cg.squads >= 2 then say("Vehicle loaded: you may only carry up to 2 squads with a vehicle.",6); return end

    if cg.squads >= cap.maxSquads or (cap.mode=="EITHER" and cg.veh and cg.squads >= 2) then
      say("Squad capacity reached.", 6); return
    end

    -- Economy per squad
    local cost = unitCostOrFallback("<INFANTRY_SQUAD>", "SQUAD")
    if not econ_can(af, side, cost) then say("Insufficient resources at "..af.." for an infantry squad.", 6); return end
    econ_debit(af, side, cost)

    cg.squads = cg.squads + 1
    cg.fromAF = af
    say(string.format("Loaded 1 squad (total %d). Cost applied at %s.", cg.squads, af), 6)
  end)

  missionCommands.addCommandForGroup(gid, "Load Vehicle", root, function()
    local u = g:getUnit(1); if not u then return end
    local t = u:getTypeName(); if not heloTypeAllowed(t) then say("This helicopter is not allowed to pickup.",6); return end
    if not heloLanded(u) then say("Land and stop inside an OWNED airfield zone to load.", 6); return end

    local side = sideStrFromCoal(u:getCoalition())
    local p = u:getPoint(); local pt = {x=p.x, z=p.z}
    local z, af = airfieldZoneAndNameForPoint(pt, side)
    if not z or not af then say("Not inside an OWNED airfield zone.", 6); return end

    local cap = ALLOWED[t]
    if (cap.maxVehicle or 0) < 1 then say("This helicopter cannot carry a vehicle.", 6); return end

    local cg = cargoFor(g:getName())
    if cg.veh then say("You already have a vehicle loaded.", 6); return end
    if cap.mode=="EITHER" and cg.squads > 2 then say("Too many squads onboard for a vehicle (max 2 with a vehicle).",6); return end

    -- Choose vehicle type now (so we can debit precise cost if UNITS supplies it)
    local vehType = PICKUP.cfg.VEHICLE_TYPES[side] and PICKUP.cfg.VEHICLE_TYPES[side][math.random(#PICKUP.cfg.VEHICLE_TYPES[side])] or pickVehicleType(side)
    if not vehType then say("No vehicle types available for "..side.." (configure CONFIG.PICKUP.VEHICLE_TYPES or UNITS.GROUND).", 10); return end
    local cost = unitCostOrFallback(vehType, "VEH")
    if not econ_can(af, side, cost) then say("Insufficient resources at "..af.." for "..vehType..".", 6); return end
    econ_debit(af, side, cost)

    cg.veh = true; cg.vehType = vehType; cg.fromAF = af
    say(string.format("Loaded vehicle: %s. Cost applied at %s.", vehType, af), 6)
  end)

  missionCommands.addCommandForGroup(gid, "Unload Here", root, function()
    local u = g:getUnit(1); if not u then return end
    if not heloLanded(u) then say("Land and stop to unload.", 6); return end
    local side = sideStrFromCoal(u:getCoalition())

    local p = u:getPoint(); local here = {x=p.x, z=p.z}
    local cg = cargoFor(g:getName())
    if (cg.squads <= 0) and (not cg.veh) then say("No cargo onboard.", 6); return end

    -- Determine if we are inside any AF zone, and whether it is enemy
    local zone, afName = airfieldZoneAndNameForPoint(here, nil)
    local enemyAF = nil
    if zone and afName then
      local own = ownerStr(afName)
      if own and own ~= side then enemyAF = { name=afName, zone=zone } end
    end

    -- Spawn squads
    local spawned = {}
    for _=1,(cg.squads or 0) do
      local grp = select(1, spawnInfantrySquad(side, here, "INF", true)) -- playerCanDrive squads (harmless with CA)
      if grp then beginIdleWatch(grp); spawned[#spawned+1] = grp end
    end

    -- Spawn vehicle
    if cg.veh then
      local vGrp = select(1, spawnVehicle(side, here, "VEH", true, cg.vehType))
      if vGrp then beginIdleWatch(vGrp); spawned[#spawned+1] = vGrp end
    end

    -- If deployed within enemy AF zone -> attack that AF
    if enemyAF then
      for _,gr in ipairs(spawned) do
        setGroundROE(gr:getController())
        orderMove(gr, { x=enemyAF.zone.x, z=enemyAF.zone.z })
        timer.scheduleFunction(function()
          taskSearchAndEngage(gr, {x=enemyAF.zone.x, z=enemyAF.zone.z}, enemyAF.zone.r or 800)
        end, {}, now() + 5)
      end
      say(string.format("Deployed in enemy zone: %s — move/attack ordered.", enemyAF.name), 8)
    else
      -- Else: hold/guard here with weapon free
      for _,gr in ipairs(spawned) do
        setGroundROE(gr:getController())
        taskSearchAndEngage(gr, here, 500)
      end
      say("Deployed: guarding this area. Will despawn if idle.", 8)
    end

    resetCargo(g:getName())
  end)
end

---------------------------------------------------------------------
-- Hook into client helicopter births to attach menu
---------------------------------------------------------------------
local EH = {}
function EH:onEvent(e)
  if not e or not e.id then return end
  if e.id == world.event.S_EVENT_BIRTH and e.initiator then
    local u = e.initiator
    if not (u and u.getCategory and u:getCategory() == Object.Category.UNIT) then return end
    local t = u:getTypeName()
    if not heloTypeAllowed(t) then return end
    local g = groupFromUnit(u)
    if not g then return end
    -- Only attach to player/client helos
    local u1 = g:getUnit(1)
    if u1 and (u1:getPlayerName() or (u1:getSkill() == "Client" or u1:getSkill() == "Player")) then
      buildMenusForGroup(g)
      dbg("Pickup menu attached to "..(g:getName() or "?"))
    end
  end
end
world.addEventHandler(EH)

---------------------------------------------------------------------
-- Init
---------------------------------------------------------------------
function PICKUP.init(cfg)
  if PICKUP._armed then return end
  if cfg and type(cfg)=="table" then
    -- merge shallow
    for k,v in pairs(cfg) do PICKUP.cfg[k] = v end
  end
  PICKUP._armed = true
  timer.scheduleFunction(function() return pollIdle() end, {}, now() + PICKUP.cfg.MOVE_CHECK_SEC)
  say("PICKUP.lua loaded.", 5)
end

-- Auto-init after load if not bootstrapped by OPERATIONINIT
pcall(function() trigger.action.outText("PICKUP.lua LOADED...).", 5) end)
if not PICKUP._armed then PICKUP.init() end
return PICKUP
