-- NAVAL.lua — Fleet spawner/manager for Operation Cold-War Breach
-- Roles: "PATROL", "STRIKE", "SHORE" (shore bombardment)
-- Routes: zones "SEA_<Route>_1..20" preferred; fallback "NAVAL_<From>_to_<To>_<i>"
-- Integrations: STATE (economy), UNITS (ship catalogs), CONFIG (tuning), TERRAIN (optional helpers)

NAVAL = NAVAL or {}

---------------------------------------------------------------------
-- Utils
---------------------------------------------------------------------
local function say(t, d) trigger.action.outText("[NAVAL] "..tostring(t), d or 5) end
local function now() return timer.getTime() end
local function info(t) if env and env.info then env.info("[NAVAL] "..tostring(t)) end end
local function fmt(...) return string.format(...) end
local function pick(t) if type(t)=="table" and #t>0 then return t[math.random(#t)] end end

local function getZone(name)
  if not name then return nil end
  local z = trigger.misc.getZone(name)
  if z and z.point then return { name=name, x=z.point.x, y=0, z=z.point.z, r=z.radius or 1500 } end
  return nil
end

local function dist2D(a,b) local dx=a.x-b.x; local dz=a.z-b.z; return math.sqrt(dx*dx+dz*dz) end

local function countryFor(sideStr)
  if CONFIG and CONFIG.GROUND and CONFIG.GROUND.COUNTRY and CONFIG.GROUND.COUNTRY[sideStr] then
    return CONFIG.GROUND.COUNTRY[sideStr]
  end
  return (sideStr=="RED") and country.id.RUSSIA or country.id.USA
end

local function ownerStr(af)
  if TERRAIN and TERRAIN.getOwner then
    local o = TERRAIN.getOwner(af)
    if o=="BLUE" or o==coalition.side.BLUE or o==2 then return "BLUE" end
    if o=="RED"  or o==coalition.side.RED  or o==1 then return "RED"  end
  end
  return nil
end

---------------------------------------------------------------------
-- Config (tunable via CONFIG.NAVAL)
---------------------------------------------------------------------
NAVAL.cfg = {
  MAX_ACTIVE_PER_ROUTE     = (CONFIG and CONFIG.NAVAL and CONFIG.NAVAL.MAX_ACTIVE_PER_ROUTE) or 1,
  RESPAWN_COOLDOWN_SEC     = (CONFIG and CONFIG.NAVAL and CONFIG.NAVAL.RESPAWN_COOLDOWN_SEC) or 7200, -- ToDo asks 2h; editable
  CATASTROPHIC_LOSS_FRAC   = (CONFIG and CONFIG.NAVAL and CONFIG.NAVAL.CATASTROPHIC_LOSS_FRAC) or 0.60,
  DEBUG                    = (CONFIG and CONFIG.NAVAL and CONFIG.NAVAL.debug) or false,
}

local function dbg(t) if NAVAL.cfg.DEBUG then trigger.action.outText("[NAVAL:DBG] "..tostring(t), 6) end end

---------------------------------------------------------------------
-- Economy adapters
---------------------------------------------------------------------
local function econ_can(cost, hubOrAF, side)
  if not cost then return true end
  if STATE and STATE.canAfford then return STATE.canAfford(hubOrAF or "SEA", side, cost) end
  if STATE and STATE.econ and STATE.econ.canAfford then return STATE.econ.canAfford(hubOrAF or "SEA", side, cost) end
  return true
end
local function econ_debit(cost, hubOrAF, side)
  if not cost then return true end
  if STATE and STATE.debit then return STATE.debit(hubOrAF or "SEA", side, cost) end
  if STATE and STATE.econ and STATE.econ.debit then return STATE.econ.debit(hubOrAF or "SEA", side, cost) end
  return true
end

---------------------------------------------------------------------
-- Catalogs & costs
---------------------------------------------------------------------
local function typesFor(side, role)
  -- CONFIG.NAVAL.TEMPLATES[side][role] or UNITS.NAVAL[side][role] -> { "Type", "Type", ... }
  if CONFIG and CONFIG.NAVAL and CONFIG.NAVAL.TEMPLATES and CONFIG.NAVAL.TEMPLATES[side] and CONFIG.NAVAL.TEMPLATES[side][role] then
    return CONFIG.NAVAL.TEMPLATES[side][role]
  end
  if UNITS and UNITS.NAVAL and UNITS.NAVAL[side] and UNITS.NAVAL[side][role] then
    return UNITS.NAVAL[side][role]
  end
  -- sensible fallbacks
  if role=="TANKER" then return { (side=="RED") and "Dry-cargo ship-2" or "Dry-cargo ship-2" } end
  if side=="RED" then
    return (role=="SHORE" or role=="STRIKE") and { "BDK-775", "REZKY" } or { "REZKY" }
  else
    return (role=="SHORE" or role=="STRIKE") and { "PERRY", "USS_Samuel_Chase" } or { "PERRY" }
  end
end

local function fleetCost(side, role)
  if CONFIG and CONFIG.NAVAL and CONFIG.NAVAL.COST and CONFIG.NAVAL.COST[role] then
    return CONFIG.NAVAL.COST[role]
  end
  -- modest defaults; tune in CONFIG
  if role=="SHORE" then return { mp=10, ammo=60, fuel=120 } end
  if role=="STRIKE" then return { mp=8,  ammo=40, fuel=100 } end
  return { mp=6, ammo=20, fuel=80 } -- PATROL
end

---------------------------------------------------------------------
-- Waypoints
---------------------------------------------------------------------
local MAX_WP = 30
local function collectSeaWPs(routeName, from, to)
  local list = {}
  if routeName then
    for i=1,MAX_WP do
      local z = getZone(fmt("SEA_%s_%d", routeName, i))
      if z then list[#list+1] = z else break end
    end
  end
  if #list == 0 and from and to then
    for i=1,MAX_WP do
      local z = getZone(fmt("NAVAL_%s_to_%s_%d", from, to, i))
      if z then list[#list+1] = z else break end
    end
  end
  return list
end

local function wpTurn(x,z,speed)
  return { x=x, y=z, type="Turning Point", action="Turning Point", speed=speed or 13, speed_locked=true, ETA=0, ETA_locked=false }
end

---------------------------------------------------------------------
-- Group helpers
---------------------------------------------------------------------
local function countAlive(group)
  if not group or not group.isExist or not group:isExist() then return 0,0 end
  local t,a=0,0
  for _,u in ipairs(group:getUnits() or {}) do
    t=t+1
    if u and u.isExist and u:isExist() and u:getLife()>0 then a=a+1 end
  end
  return a,t
end

local function assignRoute(group, wps)
  if not (group and group.isExist and group:isExist() and wps and #wps>0) then return end
  local ctrl = group:getController()
  if ctrl then pcall(function() ctrl:setTask({ id='Mission', params={ route={ points=wps } } }) end) end
end

---------------------------------------------------------------------
-- State
---------------------------------------------------------------------
NAVAL._routes   = NAVAL._routes   or {} -- key -> { side=, role=, from=, to=, routeName= }
NAVAL._active   = NAVAL._active   or {} -- key -> { [groupName]=true }
NAVAL._cooldown = NAVAL._cooldown or {} -- key -> t_expires
NAVAL._armed    = NAVAL._armed    or false

local function routeKey(side, routeName, from, to, role)
  return fmt("%s|%s|%s->%s|%s", side or "?", routeName or "-", from or "-", to or "-", role or "-")
end

local function canSpawnOnRoute(key)
  local bucket = NAVAL._active[key] or {}
  local alive=0
  for gname,_ in pairs(bucket) do
    local g = Group.getByName(gname)
    if g and g:isExist() then alive=alive+1 else bucket[gname]=nil end
  end
  NAVAL._active[key] = bucket
  return alive < (NAVAL.cfg.MAX_ACTIVE_PER_ROUTE or 1)
end

local function registerActive(key, groupName)
  NAVAL._active[key] = NAVAL._active[key] or {}
  NAVAL._active[key][groupName] = true
end

---------------------------------------------------------------------
-- Spawner
---------------------------------------------------------------------
local function spawnFleet(side, role, routeName, from, to)
  local key = routeKey(side, routeName, from, to, role)
  local cd  = NAVAL._cooldown[key] or 0
  if now() < cd then dbg("Cooldown active for "..key); return nil,"cooldown" end
  if not canSpawnOnRoute(key) then dbg("Route cap reached for "..key); return nil,"cap" end

  -- Waypoints
  local wps = collectSeaWPs(routeName, from, to)
  if #wps == 0 then
    dbg("No sea waypoints for "..key); return nil,"no wps"
  end

  -- Fleet composition
  local types = typesFor(side, role)
  if not types or #types==0 then dbg("No ship types for "..key); return nil,"types" end

  local ctry = countryFor(side)
  local gname = fmt("NAV_%s_%s_%06d", side, role, math.random(999999))
  local units = {}
  local spacing = 60
  for i,tname in ipairs(types) do
    local x, z = wps[1].x + (i-1)*spacing, wps[1].z + (i-1)*spacing
    units[#units+1] = { name=gname.."_U"..i, type=tname, skill="Average", x=x, y=z, heading=0 }
  end

  local tpl = {
    visible=false, lateActivation=false, tasks={}, task="Anti-ship",
    route={ points = (function()
      local pts = {}
      for _,z in ipairs(wps) do pts[#pts+1] = wpTurn(z.x, z.z, 13) end
      -- loop back to first to keep patrolling
      pts[#pts+1] = wpTurn(wps[1].x, wps[1].z, 13)
      return pts
    end)() },
    units=units,
    name=gname
  }

  -- Economy
  local cost = fleetCost(side, role)
  if not econ_can(cost, from or "SEA", side) then
    say(fmt("%s %s fleet refused: insufficient resources.", side, role), 6)
    return nil,"econ"
  end

  local grp = coalition.addGroup(ctry, Group.Category.SHIP, tpl)
  if not grp then return nil,"spawn" end
  econ_debit(cost, from or "SEA", side)

  registerActive(key, gname)
  NAVAL._routes[gname] = { key=key, side=side, role=role, routeName=routeName, from=from, to=to, spawned=now(), lastAlive=now() }

  say(fmt("%s %s fleet departed (%s).", side, role, routeName or (from.."→"..to)), 6)
  return grp
end

---------------------------------------------------------------------
-- Lifecycle / loss handling
---------------------------------------------------------------------
local function onCatastrophicLoss(groupName, rec)
  local g = Group.getByName(groupName)
  if g and g:isExist() then
    say(fmt("%s fleet suffered catastrophic losses; scuttling remnants.", rec.side), 6)
    pcall(function() g:destroy() end)
  end
  NAVAL._cooldown[rec.key] = now() + (NAVAL.cfg.RESPAWN_COOLDOWN_SEC or 7200)
end

local function tickFleets()
  for gname, rec in pairs(NAVAL._routes) do
    local g = Group.getByName(gname)
    if not g or not g:isExist() then
      -- dead → start cooldown (if not already set)
      if not NAVAL._cooldown[rec.key] then
        NAVAL._cooldown[rec.key] = now() + (NAVAL.cfg.RESPAWN_COOLDOWN_SEC or 7200)
        dbg("Fleet gone; cooldown set for "..rec.key)
      end
      -- remove from buckets
      if NAVAL._active[rec.key] then NAVAL._active[rec.key][gname] = nil end
      NAVAL._routes[gname] = nil
    else
      -- loss check
      local a,t = (function()
        local al, tot = 0,0
        for _,u in ipairs(g:getUnits() or {}) do
          tot=tot+1
          if u and u:isExist() and u:getLife()>0 then al=al+1 end
        end
        return al, tot
      end)()
      if t>0 then
        local lossFrac = (t - a) / t
        if lossFrac >= (NAVAL.cfg.CATASTROPHIC_LOSS_FRAC or 0.60) then
          onCatastrophicLoss(gname, rec)
        end
      end
    end
  end
  return now() + 20
end

local function tickRespawns()
  -- If a route is in cooldown and has no active fleet, try to respawn after cooldown
  for key, texp in pairs(NAVAL._cooldown) do
    if now() >= texp then
      local bucket = NAVAL._active[key] or {}
      local alive=0
      for n,_ in pairs(bucket) do local g=Group.getByName(n); if g and g:isExist() then alive=alive+1 end end
      if alive==0 then
        -- decode key
        local side, routeName, from_to, role = key:match("^([^|]+)|([^|]+)|([^|]+)|([^|]+)$")
        local from, to = nil, nil
        if from_to and from_to ~= "-" then
          from, to = from_to:match("^([^%-]+)%-%>(.+)$")
        end
        spawnFleet(side, role ~= "-" and role or "PATROL", routeName ~= "-" and routeName or nil, from, to)
        NAVAL._cooldown[key] = nil
      end
    end
  end
  return now() + 30
end

---------------------------------------------------------------------
-- Shore bombardment helper (optional)
---------------------------------------------------------------------
local function bombardTask(group, targetZoneName)
  local z = getZone(targetZoneName); if not z then return end
  local ctrl = group and group.getController and group:getController() or nil
  if not ctrl then return end
  -- DCS has 'FireAtPoint' for artillery; ships support it for naval guns
  timer.scheduleFunction(function()
    if not (group and group:isExist()) then return nil end
    pcall(function() ctrl:pushTask({ id='FireAtPoint', params={ point={x=z.x, y=0, z=z.z}, radius=80 } }) end)
    return now() + 45
  end, {}, now()+5)
end

---------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------
-- Spawn a fleet by abstract route name (uses zones SEA_<route>_1..N)
-- opts = { side="BLUE"/"RED", role="PATROL"/"STRIKE"/"SHORE", route="NorthCorridor" }
function NAVAL.spawnRoute(opts)
  opts = opts or {}
  local side = opts.side or "BLUE"
  local role = opts.role or "PATROL"
  local route = opts.route
  return spawnFleet(side, role, route, nil, nil)
end

-- Spawn a fleet by (from->to) pair (uses NAVAL_<From>_to_<To>_i waypoints)
-- opts = { side="BLUE"/"RED", role="PATROL"/"STRIKE"/"SHORE", from="Evenes", to="Bodo" }
function NAVAL.spawnFromTo(opts)
  opts = opts or {}
  return spawnFleet(opts.side or "BLUE", opts.role or "PATROL", nil, opts.from, opts.to)
end

-- Order the nearest friendly fleet on a route to bombard a target AF zone (or any zone name)
-- NAVAL.requestBombard({ side="BLUE", route="NorthCorridor", targetZone="BOMBARD_Bodo" })
function NAVAL.requestBombard(opts)
  opts = opts or {}
  local side = opts.side or "BLUE"
  local route = opts.route
  local target = opts.targetZone
  if not (route and target) then say("NAVAL.requestBombard missing route/target.", 6); return end

  -- find any active group on this route/side
  local key = routeKey(side, route, nil, nil, "SHORE")  -- accept any role; broaden search
  local candidates = {}
  for gname,_ in pairs(NAVAL._routes) do
    local rec = NAVAL._routes[gname]
    if rec.side==side and rec.routeName==route then
      local g=Group.getByName(gname)
      if g and g:isExist() then candidates[#candidates+1] = g end
    end
  end
  if #candidates==0 then say("No naval group on that route.", 6); return end

  local zt = getZone(target); if not zt then say("Target zone not found.", 6); return end
  local best,bd=nil, 1e18
  for _,g in ipairs(candidates) do
    local u=g:getUnit(1); if u and u:isExist() then
      local p=u:getPoint(); local d=dist2D({x=p.x,z=p.z}, {x=zt.x,z=zt.z})
      if d<bd then best,bd=g,d end
    end
  end
  if best then bombardTask(best, target); say("Naval guns: engaging shore target.", 6) end
end

-- Initialize scanners and optional startup fleets from CONFIG.NAVAL.STARTUP_FLEETS
function NAVAL.init()
  if NAVAL._armed then return end
  NAVAL._armed = true
  timer.scheduleFunction(function() return tickFleets()   end, {}, now()+10)
  timer.scheduleFunction(function() return tickRespawns() end, {}, now()+15)

  -- Startup fleets (optional):
  -- CONFIG.NAVAL.STARTUP_FLEETS = {
  --   { side="BLUE", role="PATROL", route="NorthCorridor" },
  --   { side="RED",  role="STRIKE", from="Murmansk", to="Bodo" },
  -- }
  if CONFIG and CONFIG.NAVAL and CONFIG.NAVAL.STARTUP_FLEETS then
    for _,f in ipairs(CONFIG.NAVAL.STARTUP_FLEETS) do
      if f.route then
        NAVAL.spawnRoute({ side=f.side, role=f.role, route=f.route })
      else
        NAVAL.spawnFromTo({ side=f.side, role=f.role, from=f.from, to=f.to })
      end
    end
  end

  dbg("NAVAL initialized.")
end

pcall(function() trigger.action.outText("NAVAL.lua LOADED...).", 5) end)
info("NAVAL.lua loaded.")
