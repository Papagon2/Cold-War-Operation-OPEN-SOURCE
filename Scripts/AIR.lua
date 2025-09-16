-- AIR.lua — Air war director for Operation Cold-War Breach
-- Roles: CAP, CAS, STRIKE, BOMB, RECON, AWACS, TANKER, TRANSPORT (helo)
-- Spawns only from *active* frontline airfields (via TERRAIN), checks STATE economy,
-- applies LOADOUT/PYLONS, maintains caps/timers, and RTB/respawns on capture.

AIR = AIR or {}

---------------------------------------------------------------------
-- Tiny utils
---------------------------------------------------------------------
local function now() return timer.getTime() end
local function say(t,d) trigger.action.outText("[AIR] "..tostring(t), d or 6) end
local function info(t) if env and env.info then env.info("[AIR] "..tostring(t)) end end

local function safe(tbl,k,def) if tbl and tbl[k]~=nil then return tbl[k] end return def end
local function tblcount(t) local c=0; for _ in pairs(t or {}) do c=c+1 end return c end

local function toSideStr(side)
  if side=="BLUE" or side==coalition.side.BLUE or side==2 then return "BLUE" end
  if side=="RED"  or side==coalition.side.RED  or side==1 then return "RED"  end
  return "NEUTRAL"
end
local function toCoalition(sideStr) return (sideStr=="RED") and coalition.side.RED or coalition.side.BLUE end

local function pointFromZone(zName)
  local z = zName and trigger.misc.getZone(zName) or nil
  if z and z.point then
    return {
      x   = z.point.x,
      z   = z.point.z,
      alt = land.getHeight({ x = z.point.x, y = z.point.z }),
      r   = z.radius or 1500
    }
  end
  return nil
end

-- Heavy roles / types need staggered spawning (few stands, long start-up)
local HEAVY_TYPES = {
  ["E-3A"]=true, ["A-50"]=true, ["KC-135"]=true, ["KC-135MPRS"]=true, ["IL-78M"]=true,
  ["B-52H"]=true, ["Tu-22M3"]=true, ["Su-24M"]=true, ["F-111F"]=true
}

local function isHeavy(role, unitType)
  if role=="AWACS" or role=="TANKER" or role=="BOMB" then return true end
  return HEAVY_TYPES[unitType] and true or false
end

local function afHomePoint(af)
  -- Dedicated spawn zone preferred; fall back to CAP_<AF>
  local z = pointFromZone("Z_AIRFIELD_"..af) or pointFromZone("CAP_"..af)
  return z and { x = z.x, z = z.z, alt = z.alt } or nil
end

local function orbitAnchor(af, role)
  -- Zones: CAP_<AF>, AEW_<AF> (or <AF>_AWS in your list), TANKER_<AF>
  local map = {
    CAP     = "CAP_"..af,
    CAS     = "CAP_"..af,
    STRIKE  = "CAP_"..af,
    BOMB    = "CAP_"..af,
    RECON   = "CAP_"..af,
    AWACS   = (pointFromZone("AEW_"..af) and "AEW_"..af) or (pointFromZone(af:upper().."_AWS") and af:upper().."_AWS") or ("CAP_"..af),
    TANKER  = (pointFromZone("TANKER_"..af) and "TANKER_"..af) or (pointFromZone(af:upper().."_TANKER") and af:upper().."_TANKER") or ("CAP_"..af),
    TRANSPORT = "CAP_"..af,
  }
  local z = pointFromZone(map[role] or ("CAP_"..af))
  return z
end

local function groupAlive(name) local g=Group.getByName(name); return g and g:isExist() end

---------------------------------------------------------------------
-- Config view (ALL editable in CONFIG.AIR)
---------------------------------------------------------------------
AIR.cfg = AIR.cfg or (CONFIG and CONFIG.AIR) or {}
local C = AIR.cfg

-- Master toggles / role counts per AF (per side)
C.ENABLED            = safe(C, "ENABLED", true)
C.TICK               = safe(C, "TICK", 60)                     -- management tick
C.MAX_ACTIVE_GROUPS  = safe(C, "MAX_ACTIVE_GROUPS", 12)        -- global air cap per side
C.ROLE_COUNTS        = C.ROLE_COUNTS or {                      -- how many groups per AF to maintain
  CAP=1, CAS=1, STRIKE=0, BOMB=0, RECON=0, AWACS=1, TANKER=1, TRANSPORT=0
}

-- Spawn/respawn timings (minutes)
C.PATROL_MIN         = safe(C, "PATROL_MIN", 20)               -- orbit time per group before RTB
C.MISSION_MIN        = safe(C, "MISSION_MIN", 45)              -- hard kill after this (safety)
C.RESPAWN_DELAY_MIN  = safe(C, "RESPAWN_DELAY_MIN", 10)        -- after group ends
C.HEAVY_LOCK_SEC      = safe(C, "HEAVY_LOCK_SEC", 180)  -- after spawning a heavy at an AF, block other heavies for N sec
C.SPAWN_ONE_PER_AF_TICK = safe(C, "SPAWN_ONE_PER_AF_TICK", true) -- only one new group per AF per upkeep tick

-- Spawn posture per role (hot vs cold)
C.SPAWN_COLD_ROLES   = C.SPAWN_COLD_ROLES or { AWACS=true, TANKER=true, TRANSPORT=true }
-- Fighters/attackers spawn "parking-hot" by default

-- Economy integration (lightweight & editable)
-- If you have detailed per-type fuel/crew tables, put them in CONFIG.AIR.CREW_BY_TYPE and FUEL_GAL_BY_TYPE.
C.CREW_BY_TYPE       = C.CREW_BY_TYPE       or {}              -- e.g., ["F-14A-135-GR"]=2
C.FUEL_GAL_BY_TYPE   = C.FUEL_GAL_BY_TYPE   or {}              -- e.g., ["F-14A-135-GR"]=4000
C.AMMO_COST_BY_ROLE  = C.AMMO_COST_BY_ROLE  or {               -- rough ammo debit per spawn
  CAP=2, CAS=8, STRIKE=12, BOMB=16, RECON=0, AWACS=0, TANKER=0, TRANSPORT=0
}

-- Types by side/role (editable). Falls back to UNITS or sane defaults if missing.
C.TYPE_BY_ROLE = C.TYPE_BY_ROLE or {
  BLUE = { CAP="F-4E-45MC", CAS="A-10A", STRIKE="F-111F", BOMB="B-52H", RECON="An-30M", AWACS="E-3A", TANKER="KC-135", TRANSPORT="CH-47Fbl1" },
  RED  = { CAP="MiG-23MLD", CAS="Su-25T", STRIKE="Su-24M", BOMB="Tu-22M3", RECON="An-30M", AWACS="A-50", TANKER="IL-78M", TRANSPORT="Mi-8MT" },
}

-- Loadout mapping (role -> LOADOUT name), if you prefer named presets
C.LOADOUTS = C.LOADOUTS or {}

---------------------------------------------------------------------
-- Live registry
---------------------------------------------------------------------
AIR.live = AIR.live or {
  BLUE = { groups={}, lastSpawnByRole={}, pendingRefresh=false },
  RED  = { groups={}, lastSpawnByRole={}, pendingRefresh=false },
}
AIR.aflock = AIR.aflock or {}  -- [af] = unlock_time (seconds)
-- Per-group record: { name, role, side, af, start_t, patrol_t, mission_t }

---------------------------------------------------------------------
-- STATE / TERRAIN adapters
---------------------------------------------------------------------
local function ownerOf(af)
  if TERRAIN and TERRAIN.getOwner then return toSideStr(TERRAIN.getOwner(af)) end
  return "NEUTRAL"
end

local function airfieldsOnFront()
  local set = {}
  if TERRAIN and TERRAIN.getActiveFrontPairs then
    for _,p in ipairs(TERRAIN.getActiveFrontPairs()) do
      set[p.from]=true; set[p.to]=true
    end
  end
  local out = {}
  for af,_ in pairs(set) do out[#out+1] = af end
  table.sort(out); return out
end

local function canAffordSpawn(af, sideStr, unitType, role)
  if not STATE then return true end
  local crew = C.CREW_BY_TYPE[unitType] or 1
  local fuel = C.FUEL_GAL_BY_TYPE[unitType] or 0
  local ammo = C.AMMO_COST_BY_ROLE[role] or 0
  local cost = STATE.buildCost and STATE.buildCost{
    crew=crew, missiles=ammo, isAircraft=true, fuelGallons=fuel
  } or { mp= (crew<=1 and 10) or (crew==2 and 15) or 20, ammo=ammo, fuel=fuel }
  return (STATE.canAfford and STATE.canAfford(af, sideStr, cost)) or (STATE.hasResources and STATE.hasResources(af, sideStr, cost)) or true, cost
end

local function debitSpawn(af, sideStr, cost)
  if not STATE or not cost then return true end
  return (STATE.debit and STATE.debit(af, sideStr, cost)) or (STATE.consume and STATE.consume(af, sideStr, cost)) or true
end

---------------------------------------------------------------------
-- LOADOUT / PYLONS application
---------------------------------------------------------------------
local function applyLoadout(groupName, role)
  -- Try role→preset mapping first (LOADOUT delegates to PYLONS correctly)
  if LOADOUT and LOADOUT.applyGroupRole then
    local ok = pcall(LOADOUT.applyGroupRole, groupName, role)
    if ok then return true end
  end

  -- Fallback to explicit preset name
  local preset = (CONFIG and CONFIG.AIR and CONFIG.AIR.LOADOUTS) and CONFIG.AIR.LOADOUTS[role]
  if preset and LOADOUT and LOADOUT.applyByName then
    local ok = pcall(LOADOUT.applyByName, groupName, preset)
    if ok then return true end
  end

  -- Final direct call to PYLONS (correct signature is (group, presetName))
  if preset and PYLONS and PYLONS.applyForGroup then
    local ok = pcall(PYLONS.applyForGroup, groupName, preset)
    if ok then return true end
  end
  return false
end

---------------------------------------------------------------------
-- Group creation helpers
---------------------------------------------------------------------
AIR._t0           = AIR._t0 or timer.getTime()
AIR._nextSpawn    = AIR._nextSpawn or 0
AIR._orderIndex   = AIR._orderIndex or 1

local function now() return timer.getTime() end

local function spawnOrder()
  local cfg = (CONFIG and CONFIG.AIR and CONFIG.AIR.SPAWN) or {}
  return cfg.ORDER or { "CAP", "CAS", "SEAD", "STRIKE", "AWACS", "TANKER" }
end

local function withinBurst()
  local cfg = CONFIG.AIR.SPAWN.INITIAL_BURST
  if not (cfg and cfg.ENABLED) then return false end
  return (now() - AIR._t0) < (cfg.DURATION or 0)
end

local function nextInterval()
  local cfg = CONFIG.AIR.SPAWN
  if withinBurst() then
    return (cfg.INITIAL_BURST and cfg.INITIAL_BURST.INTERVAL) or 90
  end
  -- fall back to your normal interval if you have one, or 300s default
  return (CONFIG.AIR.INTERVAL or 300)
end

-- You likely already have counters for alive/active per role & side.
-- Stub versions here; wire them to your existing tracking:
local function activeCount(role, side)
  if AIR.getActiveCount then return AIR.getActiveCount(role, side) end
  return 0
end

local function canSpawnSupport(role)
  if role ~= "AWACS" and role ~= "TANKER" then return true end
  local cfg = CONFIG.AIR.SPAWN
  local delayOK = (now() - AIR._t0) >= (cfg.SUPPORT_DELAY or 0)
  if not delayOK then return false end
  local max = (cfg.MAX_ACTIVE and cfg.MAX_ACTIVE[role]) or 1
  -- If you track per-side, call twice (BLUE/RED). Otherwise keep as a global cap.
  return (activeCount(role, "BLUE") < max) or (activeCount(role, "RED") < max)
end

-- Try roles in configured order, round-robin, but skip support until allowed:
local function pickNextRole()
  local order = spawnOrder()
  if #order == 0 then return nil end
  local idx = AIR._orderIndex
  for _ = 1, #order do
    local role = order[idx]
    idx = (idx % #order) + 1
    if canSpawnSupport(role) then
      AIR._orderIndex = idx
      return role
    end
  end
  -- If all were blocked (e.g., still within SUPPORT_DELAY), try only non-support
  for i = 1, #order do
    local role = order[i]
    if role ~= "AWACS" and role ~= "TANKER" then
      AIR._orderIndex = ((i % #order) + 1)
      return role
    end
  end
  return nil
end

local function missionTaskForRole(role)
  if role=="AWACS"      then return "AWACS"
  elseif role=="TANKER" then return "Refueling"
  elseif role=="CAP"    then return "CAP"
  elseif role=="CAS"    then return "CAS"
  elseif role=="STRIKE" or role=="BOMB" then return "Ground Attack"
  elseif role=="RECON"  then return "Reconnaissance"
  elseif role=="TRANSPORT" then return "Transport"
  else return "CAS" end
end

local function airbaseIdFor(af, home)
  -- Try exact mission name first
  local ab = Airbase.getByName(af)
  if not ab and TERRAIN and TERRAIN.AIRFIELDS and TERRAIN.AIRFIELDS[af] then
    local alt = TERRAIN.AIRFIELDS[af].airbase or TERRAIN.AIRFIELDS[af].name
    if alt then ab = Airbase.getByName(alt) end
  end
  -- Fallback: nearest airbase to our home point (if available)
  if (not ab) and home and world.getAirbases then
    local nearest, best = nil, 1e12
    for _,a in ipairs(world.getAirbases()) do
      local p = a:getPoint()
      local dx, dz = (p.x - home.x), (p.z - home.z)
      local d2 = dx*dx + dz*dz
      if d2 < best then best = d2; nearest = a end
    end
    ab = nearest
  end
  return (ab and ab:getID()) or nil
end

local function spawnPostureFor(role)
  return (C.SPAWN_COLD_ROLES[role] and "COLD") or "HOT"
end

local function defaultAlt(role)
  if role=="AWACS" then return 9144 elseif role=="TANKER" then return 7620 else return 7000 end
end
local function defaultSpeed(role)
  if role=="AWACS" or role=="TANKER" then return 220 else return 300 end
end

local function buildWP(x, y, alt, spd, action, airdromeId, wpType)
  return {
    type   = wpType or "Turning Point",
    action = action or "Turning Point",
    x = x, y = y, alt = alt, speed = spd,
    speed_locked = true, alt_type = "BARO", tasks = {},
    airdromeId = airdromeId
  }
end

local function addOrbitTask(wp, role)
  local spd, alt = defaultSpeed(role), defaultAlt(role)
  local task = { id='Orbit', params={ pattern = (role=="TANKER") and "Race-Track" or "Circle", speed=spd, altitude=alt } }
  if role=="TANKER" then
    task.params.length  = safe(C, "TANKER_RACETRACK_LEN", 15000)
    task.params.heading = safe(C, "TANKER_RACETRACK_HDG", 90)
  end
  table.insert(wp.tasks, task)
  if role=="TANKER" then table.insert(wp.tasks, { id="Refueling", params={} }) end
end

local function pickType(sideStr, role)
  local t = (C.TYPE_BY_ROLE and C.TYPE_BY_ROLE[sideStr] and C.TYPE_BY_ROLE[sideStr][role]) or nil
  if not t and UNITS and UNITS.AIR and UNITS.AIR[sideStr] and UNITS.AIR[sideStr][role] then
    local lst = UNITS.AIR[sideStr][role]; t = lst[math.random(#lst)]
  end
  -- sane defaults if everything missing
  if not t then
    if role=="AWACS" then t = (sideStr=="RED") and "A-50" or "E-3A"
    elseif role=="TANKER" then t = (sideStr=="RED") and "IL-78M" or "KC-135"
    elseif role=="TRANSPORT" then t = (sideStr=="RED") and "Mi-8MT" or "CH-47Fbl1"
    else t = (sideStr=="RED") and "MiG-23MLD" or "F-4E-45MC" end
  end
  return t
end

---------------------------------------------------------------------
-- Spawner (returns group name or nil)
---------------------------------------------------------------------
local function spawnOne(af, sideStr, role, count)
  count = math.max(1, math.min(4, count or 2))

  -- Ownership & active-frontline gate
  if ownerOf(af) ~= sideStr then return nil,"owner" end
  local frontSet = {}
  for _,p in ipairs(TERRAIN.getActiveFrontPairs and TERRAIN.getActiveFrontPairs() or {}) do
    frontSet[p.from]=true; frontSet[p.to]=true
  end
  if not frontSet[af] then return nil,"notfront" end

  -- Orbit anchor + type + economy
  local anchor = orbitAnchor(af, role)
  if not anchor then info(string.format("%s: missing orbit zone at %s", role, af)); return nil,"nozone" end

  local unitType = pickType(sideStr, role)
  local okCost, cost = canAffordSpawn(af, sideStr, unitType, role)
  if not okCost then say(string.format("%s at %s refused: insufficient economy.", role, af), 8); return nil,"econ" end

  -- Stagger heavy spawns at this AF to avoid parking collisions
  if isHeavy(role, unitType) then
    local tUnlock = AIR.aflock[af] or 0
    if now() < tUnlock then return nil, "heavylock" end
  end

  -- Global air cap per side
  local live = AIR.live[sideStr].groups or {}
  local liveCount=0; for _,rec in pairs(live) do if groupAlive(rec.name) then liveCount=liveCount+1 end end
  if liveCount >= C.MAX_ACTIVE_GROUPS then return nil,"cap" end

  -- Spawn posture / home / base
  local posture = spawnPostureFor(role)
  local home    = afHomePoint(af)
  local spd,alt = defaultSpeed(role), defaultAlt(role)

  -- Airbase ID (needed for any parking/runway takeoff)
  local abId = airbaseIdFor(af, home or anchor)

  -- Build ordered departure attempts: parking (cold/hot) → runway → airborne
  local function buildDepartureWPSequence(base)
    local seq = {}
    if abId then
      local wpType   = (posture=="COLD") and "TakeOffParking"    or "TakeOffParkingHot"
      local wpAction = (posture=="COLD") and "From Parking Area" or "From Parking Area Hot"
      seq[#seq+1] = { x=base.x, z=base.z, alt=math.max(alt*0.3,1500), spd=spd, airdromeId=abId, wpType=wpType,   action=wpAction }
      seq[#seq+1] = { x=base.x, z=base.z, alt=math.max(alt*0.3,1500), spd=spd, airdromeId=abId, wpType="TakeOff", action="From Runway" }
    end
    -- last resort: airborne at anchor
    seq[#seq+1] = { x=anchor.x, z=anchor.z, alt=alt, spd=spd, airdromeId=nil, wpType="Turning Point", action="Turning Point" }
    return seq
  end

  local base = home or anchor
  local attempts = buildDepartureWPSequence(base)

  -- Common group template pieces
  local coalitionId = toCoalition(sideStr)
  local countryId   = (UNITS and UNITS.COUNTRY_BY_SIDE and UNITS.COUNTRY_BY_SIDE[sideStr])
                      or ((sideStr=="RED") and country.id.RUSSIA or country.id.USA)
  local category    = (role=="TRANSPORT") and Group.Category.HELICOPTER or Group.Category.AIRPLANE
  local name = string.format("AIR_%s_%s_%s_%06d", role, sideStr, af, math.random(999999))

  -- Try each departure mode until coalition.addGroup succeeds
  local g
  for _,wp in ipairs(attempts) do
    local route = { points = {} }
    route.points[1] = buildWP(wp.x, wp.z, wp.alt, wp.spd, wp.action, wp.airdromeId, wp.wpType)
    route.points[2] = buildWP(anchor.x, anchor.z, alt, spd, "Turning Point")
    addOrbitTask(route.points[#route.points], role)

    local grp = {
      visible=false, lateActivation=false, tasks={}, task=missionTaskForRole(role),
      route=route, units={}, name=name
    }
    for i=1,count do
      grp.units[i] = {
        type = unitType, name = name.."_"..i, skill="High", payload={},
        speed=spd, x=route.points[1].x, y=route.points[1].y, heading=0,
        callsign={2,i,1}, alt=route.points[1].alt
      }
    end

    -- Pick preset from CONFIG.AIR.LOADOUTS for this role
    local preset = (CONFIG and CONFIG.AIR and CONFIG.AIR.LOADOUTS) and CONFIG.AIR.LOADOUTS[role]

    -- Pre-spawn templating (same approach OldAIR used)
    if preset and type(applyLoadoutIfAny)=="function" then
      pcall(applyLoadoutIfAny, grp, preset)
    end

    g = coalition.addGroup(countryId, category, grp)
    if g then break end
  end

  if not g then return nil,"spawnfail" end

  -- Loadout & economy
  applyLoadout(name, role, unitType)
  if not debitSpawn(af, sideStr, cost) then info("Warning: debit failed after spawn.") end

  -- right after: applyLoadout(name, role, unitType)
  -- add a short delayed retry (DCS can ignore immediate payload change)
  timer.scheduleFunction(function()
    if Group.getByName(name) and Group.getByName(name):isExist() then
      if LOADOUT and LOADOUT.applyGroupRole then pcall(LOADOUT.applyGroupRole, name, role) end
      local preset = (CONFIG and CONFIG.AIR and CONFIG.AIR.LOADOUTS) and CONFIG.AIR.LOADOUTS[role]
      if preset and PYLONS and PYLONS.applyForGroup then pcall(PYLONS.applyForGroup, name, preset) end
    end
  end, {}, timer.getTime() + 5)

  -- second safety retry a bit later
  timer.scheduleFunction(function()
    if Group.getByName(name) and Group.getByName(name):isExist() then
      if LOADOUT and LOADOUT.applyGroupRole then pcall(LOADOUT.applyGroupRole, name, role) end
      local preset = (CONFIG and CONFIG.AIR and CONFIG.AIR.LOADOUTS) and CONFIG.AIR.LOADOUTS[role]
      if preset and PYLONS and PYLONS.applyForGroup then pcall(PYLONS.applyForGroup, name, preset) end
    end
  end, {}, timer.getTime() + 15)

  -- Track live group
  AIR.live[sideStr].groups[name] = {
    name=name, role=role, side=sideStr, af=af,
    start_t=now(), patrol_t = C.PATROL_MIN*60, mission_t=C.MISSION_MIN*60,
    everAir=false
  }

  -- If heavy: lock this AF for a bit so another heavy won't try to spawn immediately
  if isHeavy(role, unitType) then
    AIR.aflock[af] = now() + C.HEAVY_LOCK_SEC
  end

  return true, name
end

---------------------------------------------------------------------
-- Upkeep / lifecycle
---------------------------------------------------------------------
local function despawn(name)
  local g=Group.getByName(name)
  if g and g:isExist() then pcall(function() g:destroy() end) end
end

local function needsRespawn(sideStr, role)
  local last = AIR.live[sideStr].lastSpawnByRole[role]
  if not last then return true end
  return (now() - last) >= (C.RESPAWN_DELAY_MIN*60)
end

local function roleDesiredCount(role) return math.max(0, tonumber((C.ROLE_COUNTS or {})[role] or 0)) end

local function countFor(role)
  local map = C.COUNT_BY_ROLE or {}
  return math.max(1, math.min(4, map[role] or ((role=="CAP" or role=="CAS") and 2 or 1)))
end

local ROLES = { "AWACS","TANKER","CAP","CAS","STRIKE","BOMB","RECON","TRANSPORT" }

local function upkeep()
  if not C.ENABLED then return now() + nextInterval() end
  local fronts = airfieldsOnFront()
  say("Front AFs: " .. tostring(#fronts), 15)

  -- clean registry & timers; RTB/despawn on timeouts/landed
  for sideStr,bag in pairs(AIR.live) do
    for name,rec in pairs(bag.groups) do
      local g = Group.getByName(name)
      if not g or not g:isExist() then
        bag.groups[name] = nil
      else
        local age = now() - rec.start_t

        -- Track if they’ve ever been airborne
        local anyAir = false
        for _,u in ipairs(g:getUnits() or {}) do
          if u and u:isExist() and u:inAir() then anyAir = true break end
        end
        if anyAir then rec.everAir = true end

        -- Timer-based lifecycle
        if age >= rec.mission_t then
          say(rec.role.." exceeded mission time, RTB/Despawn.", 5)
          despawn(name); bag.groups[name] = nil
        elseif age >= rec.patrol_t and rec.everAir then
          despawn(name); bag.groups[name] = nil
        end
      end
    end
  end

  -- active frontline AF list
  

  -- spawn order now follows CONFIG.AIR.SPAWN.ORDER (combat first), with support gated by SUPPORT_DELAY
  local ORDER = spawnOrder()

  for _,af in ipairs(fronts) do
    local owner = ownerOf(af)
    if owner ~= "NEUTRAL" then
      local bag = AIR.live[owner]
      local spawnedThisAF = false

      -- try roles in the configured order; only one new group per AF per tick if flag set
            -- try roles in the configured order; only one new group per AF per tick if flag set
      for _,role in ipairs(ORDER) do
        if C.SPAWN_ONE_PER_AF_TICK and spawnedThisAF then break end

        -- only proceed if support is allowed (SUPPORT_DELAY / MAX_ACTIVE)
        if canSpawnSupport(role) then
          local want = roleDesiredCount(role)
          if want > 0 then
            -- count how many we currently have from this AF for this role
            local have = 0
            for name,rec in pairs(bag.groups) do
              if rec.af == af and rec.role == role and groupAlive(name) then
                have = have + 1
              end
            end

            while have < want do
              -- respect per-role respawn delay and global side cap
              if not needsRespawn(owner, role) then break end

              local total = 0
              for _,r in pairs(bag.groups) do
                if groupAlive(r.name) then total = total + 1 end
              end
              if total >= C.MAX_ACTIVE_GROUPS then break end

              local ok,err = spawnOne(af, owner, role, countFor(role))
              if ok then
                bag.lastSpawnByRole[role] = now()
                have = have + 1
                spawnedThisAF = true
                if C.SPAWN_ONE_PER_AF_TICK then break end
              else
                if C.debug then
                  say(string.format("Skip %s @ %s (%s): %s", role, af, owner, tostring(err)), 10)
                else
                  info(string.format("Spawn %s at %s (%s) skipped: %s", role, af, owner, tostring(err)))
                end
                break
              end
            end
          end
        end
      end
    end
  end

  -- adaptive tick: faster during INITIAL_BURST, then normal
  return now() + nextInterval()
end

---------------------------------------------------------------------
-- Capture hook: on AF change, mark a refresh so new owner gets assets
---------------------------------------------------------------------
AIR.support = AIR.support or {}
function AIR.support.onCapture(af, newSideStr, oldSideStr)
  newSideStr = toSideStr(newSideStr)
  oldSideStr = toSideStr(oldSideStr)
  if newSideStr=="NEUTRAL" then return end
  -- Despawn any groups tied to that AF (both sides, just to be safe)
  for _,sideStr in ipairs({"BLUE","RED"}) do
    for name,rec in pairs(AIR.live[sideStr].groups) do
      if rec.af==af then despawn(name); AIR.live[sideStr].groups[name]=nil end
    end
    AIR.live[sideStr].pendingRefresh = true
  end
  say(string.format("Air refresh queued at %s for %s.", af, newSideStr), 6)
end

---------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------
function AIR.requestWing(opts)
  -- Simple manual request: opts={ side="BLUE", role="CAP", from="Bodo", count=2 }
  opts = opts or {}
  local side = opts.side or "BLUE"
  local role = string.upper(opts.role or "CAP")
  local from = opts.from
  if not from then say("requestWing missing 'from' AF.", 6); return nil end
  return spawnOne(from, side, role, opts.count or 2)
end

function AIR.refreshSupport(args)
  -- Force a one-off refresh on next upkeep tick
  local side = args and (args.side or args.coalition) or nil
  if side then AIR.live[side].pendingRefresh = true else AIR.live.BLUE.pendingRefresh, AIR.live.RED.pendingRefresh = true,true end
end

function AIR.init(cfg)
  AIR.cfg = cfg or AIR.cfg
  timer.scheduleFunction(function() return upkeep() end, {}, now()+5)
  say("AIR initialized.", 6)
end

info("AIR.lua loaded.")
return AIR
