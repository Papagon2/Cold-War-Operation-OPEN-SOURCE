-- GROUND.lua — rebuilt for Operation Cold-War Breach
-- Roles: TANK, ARTILLERY, AAA (AAA spawns as trucks, drives, scatters, transforms)
-- Waypoints: "WP_<From>_to_<To>_<N>", N=1..20 (optional)
-- Spawn zones:
--   TANK:      "TANK_<From>_Spawn"       -> terminal: "TANK_<To>_Attack" (optional)
--   ARTILLERY: "ARTILLERY_<From>_Spawn"  -> terminal: "ARTILLERY_<To>_FOP" (optional)
--   AAA:       "AAA_<From>_Spawn"        -> terminal: "AAA_<From>_Deploy" (recommended)
--
-- Dependencies (optional but supported): TERRAIN (owner/fronts), STATE (economy), UNITS/CONFIG (templates), FERRY (tracking)

GROUND = GROUND or {}

---------------------------------------------------------------------
-- Utilities / globals
---------------------------------------------------------------------
local function say(txt, dur) trigger.action.outText("[GROUND] " .. tostring(txt), dur or 5) end
local function now() return timer.getTime() end
local function info(msg) env.info("[GROUND] " .. tostring(msg)) end
local function fmt(...) return string.format(...) end
local function pick(t) if type(t)=="table" and #t>0 then return t[math.random(#t)] end end

local MAX_WP = 20

-- Forward declarations
local wpPoint, assignRoute, collectWaypoints, _nearestWPToZone, waitUntilInZoneThen

-- SAFE armUp: only call setOption if the enum exists in this runtime
local function armUp(ctrl)
  if not ctrl then return end
  local okROE, okALARM, okDISP = false, false, false

  if AI and AI.Option and AI.Option.Ground and AI.Option.Ground.id and AI.Option.Ground.val then
    local gid  = AI.Option.Ground.id
    local gval = AI.Option.Ground.val
    if gid.ROE and gval.ROE and gval.ROE.OPEN_FIRE then
      pcall(function() ctrl:setOption(gid.ROE, gval.ROE.OPEN_FIRE) end); okROE = true
    end
    if gid.ALARM_STATE and gval.ALARM_STATE and gval.ALARM_STATE.RED then
      pcall(function() ctrl:setOption(gid.ALARM_STATE, gval.ALARM_STATE.RED) end); okALARM = true
    end
    if gid.DISPERSION_ON_ATTACK ~= nil then
      pcall(function() ctrl:setOption(gid.DISPERSION_ON_ATTACK, true) end); okDISP = true
    end
  end

  -- fallback (air enums exist everywhere; harmless for ground)
  if (not okROE) and AI and AI.Option and AI.Option.Air and AI.Option.Air.id and AI.Option.Air.val then
    local aid  = AI.Option.Air.id
    local aval = AI.Option.Air.val
    if aid.ROE and aval.ROE and aval.ROE.OPEN_FIRE then
      pcall(function() ctrl:setOption(aid.ROE, aval.ROE.OPEN_FIRE) end)
    end
  end
end

local function getZone(name)
  if not name then return nil end
  local z = trigger.misc.getZone(name)
  if z and z.point then return { x=z.point.x, y=0, z=z.point.z, radius=z.radius } end
  return nil
end

local function getStartWP(fromAF)
  return getZone(string.format("Start_WP_%s", fromAF))
end

local function coalitionSide(sideVal)
  if sideVal=="RED" or sideVal==coalition.side.RED or sideVal==1 then return coalition.side.RED,"RED" end
  return coalition.side.BLUE,"BLUE"
end

local function ownerSideStr(af)
  if TERRAIN and TERRAIN.getOwner then
    local o = TERRAIN.getOwner(af)
    if o=="BLUE" or o==coalition.side.BLUE or o==2 then return "BLUE" end
    if o=="RED"  or o==coalition.side.RED  or o==1 then return "RED"  end
  end
  return nil
end

-- Unit templates (CONFIG.GROUND.TEMPLATES > UNITS.GROUND)
local function unitTypesFor(sideStr, role, stage) -- stage: nil|"TRUCK"|"AAA"
  local a = CONFIG and CONFIG.GROUND and CONFIG.GROUND.TEMPLATES and CONFIG.GROUND.TEMPLATES[sideStr]
  if a then
    if stage=="TRUCK" and a.AAA_TRUCK then return a.AAA_TRUCK end
    if stage=="AAA"   and a.AAA_DEF   then return a.AAA_DEF   end
    if role and a[role] then return a[role] end
  end
  local u = UNITS and UNITS.GROUND and UNITS.GROUND[sideStr]
  if u then
    if stage=="TRUCK" and u.AAA_TRUCK then return u.AAA_TRUCK end
    if stage=="AAA"   and u.AAA       then return u.AAA       end
    if role and u[role] then return u[role] end
  end
  return {}
end

-- Country id to avoid “neutral/Ukraine” issue; override in CONFIG.GROUND.COUNTRY
local function countryIdFor(sideStr, fromAF)
  if CONFIG and CONFIG.GROUND and CONFIG.GROUND.COUNTRY and CONFIG.GROUND.COUNTRY[sideStr] then
    return CONFIG.GROUND.COUNTRY[sideStr]
  end
  if TERRAIN and TERRAIN.getCountryFor then
    local cid = TERRAIN.getCountryFor(fromAF, sideStr)
    if cid then return cid end
  end
  if sideStr=="RED" then return country.id.RUSSIA end
  return country.id.USA
end

-- Snap point to nearest road
local function snapToRoad(pt)
  if not pt then return nil end
  local v2 = { x = pt.x, y = pt.z }
  local ok = land and land.getClosestPointOnRoad and land.getClosestPointOnRoad(v2)
  if ok and ok.x and ok.y then return { x = ok.x, z = ok.y } end
  return { x = pt.x, z = pt.z }
end

-- Ferry chain via CONFIG.FERRY_ROUTES["From->To"] = { {"FERRY_X_A","FERRY_X_B"}, ... }
local function getFerryChain(fromAF, toAF)
  local key = string.format("%s->%s", tostring(fromAF), tostring(toAF))
  local chain = {}
  if CONFIG and CONFIG.FERRY_ROUTES and CONFIG.FERRY_ROUTES[key] then
    for _,pair in ipairs(CONFIG.FERRY_ROUTES[key]) do
      local A = getZone(pair[1]); local B = getZone(pair[2])
      if A and B then chain[#chain+1] = { A=A, B=B, aName=pair[1], bName=pair[2] }
      else info(string.format("FERRY: missing %s or %s for %s", tostring(pair[1]), tostring(pair[2]), key)) end
    end
  end
  if #chain > 0 then info(string.format("FERRY chain %s has %d segments.", key, #chain)) return chain end
  return nil
end

-- Gentle staggering so we don’t hammer setTask on same tick
GROUND._orderSeq = GROUND._orderSeq or 0
local function orderDelay(jitterMin, jitterMax)
  GROUND._orderSeq = (GROUND._orderSeq % 20) + 1
  local base = 0.15 * GROUND._orderSeq
  return base + (math.random() * ((jitterMax or 0.6) - (jitterMin or 0.2)) + (jitterMin or 0.2))
end

-- Drive: here -> (optional Start_WP_<fromAF>) -> road join -> target (road)
local function routeToZoneOnRoad(grp, targetZ, fromAF)
  if not (grp and grp:isExist() and targetZ) then return end
  local u = grp:getUnit(1); if not u then return end
  local p = u:getPoint()
  local pts = {}

  local startWP = getStartWP(fromAF)
  if startWP then
    -- off-road nudge to Start_WP center, then on-road from there
    pts[#pts+1] = wpPoint({x=startWP.x, z=startWP.z}, 6.0, false)
    local sRoad = snapToRoad(startWP)
    pts[#pts+1] = wpPoint({x=sRoad.x, z=sRoad.z}, 8.0, true)
  else
    -- fallback: gentle random kick away from spawn before we roadsnap
    local function farHop(px, pz, dist)
      local a = math.random() * math.pi * 2
      return { x = px + math.cos(a) * dist, z = pz + math.sin(a) * dist }
    end
    local kick = farHop(p.x, p.z, math.random(180, 260))
    pts[#pts+1] = wpPoint({x=kick.x, z=kick.z}, 6.0, false)
    local hereRoad = snapToRoad({x=kick.x, z=kick.z})
    pts[#pts+1] = wpPoint({x=hereRoad.x, z=hereRoad.z}, 8.0, true)
  end

  local tgtRoad  = snapToRoad(targetZ)
  pts[#pts+1] = wpPoint({x=tgtRoad.x,  z=tgtRoad.z},  8.0, true)
  pts[#pts+1] = wpPoint({x=targetZ.x,  z=targetZ.z},  5.0, false)
  assignRoute(grp, pts)
end

---------------------------------------------------------------------
-- Economy hooks (STATE.* if present)
---------------------------------------------------------------------
local function canAfford(af, sideStr, cost)
  if STATE and STATE.canAfford then return STATE.canAfford(af, sideStr, cost) end
  if STATE and STATE.hasResources then return STATE.hasResources(af, sideStr, cost) end
  return true
end
local function debit(af, sideStr, cost)
  if STATE and STATE.debit then return STATE.debit(af, sideStr, cost) end
  if STATE and STATE.consume then return STATE.consume(af, sideStr, cost) end
  return true
end

---------------------------------------------------------------------
-- Front activity (TERRAIN.* if present)
---------------------------------------------------------------------
local function isFrontActive(fromAF, toAF)
  if TERRAIN and TERRAIN.isFrontActive then return TERRAIN.isFrontActive(fromAF, toAF) end
  local A = TERRAIN and TERRAIN.isAirfieldActive and TERRAIN.isAirfieldActive(fromAF) or false
  local B = TERRAIN and TERRAIN.isAirfieldActive and TERRAIN.isAirfieldActive(toAF)   or false
  return A or B
end

---------------------------------------------------------------------
-- Waypoint building
---------------------------------------------------------------------
function _nearestWPToZone(wpZones, zone)
  if not zone or not wpZones or #wpZones==0 then return nil end
  local bestI, bestD2 = nil, 1e18
  for i,z in ipairs(wpZones) do
    local dx, dz = z.x - zone.x, z.z - zone.z
    local d2 = dx*dx + dz*dz
    if d2 < bestD2 then bestD2, bestI = d2, i end
  end
  return bestI
end

function wpPoint(p, speedMps, onRoad)
  local alt = (land and land.getHeight) and land.getHeight({ x = p.x, y = p.z }) or 0
  return {
    x = p.x, y = p.z,
    alt = alt, alt_type = "BARO",
    action = onRoad and "On Road" or "Off Road",
    speed = speedMps or 6.0, speed_locked = true,
    type = "Turning Point",
    ETA = 0, ETA_locked = false
  }
end

function collectWaypoints(fromAF, toAF)
  local list = {}
  for i=1,MAX_WP do
    local z = getZone(fmt("WP_%s_to_%s_%d", fromAF, toAF, i))
    if z then list[#list+1] = z else break end
  end
  return list
end

local function findRoleZones(role, fromAF, toAF)
  local spawn = getZone(fmt("%s_%s_Spawn", role, fromAF))
  local terminal
  if role=="TANK" then
    terminal = getZone(fmt("TANK_%s_Attack", toAF))
  elseif role=="ARTILLERY" then
    terminal = getZone(fmt("ARTILLERY_%s_FOP", toAF))
  elseif role=="AAA" then
    -- go to the Deploy zone first; fall back to front if no Deploy zone exists
    terminal = getZone(string.format("AAA_%s_Deploy", fromAF))
            or getZone(fromAF)
  end
  return spawn, terminal
end

-- Build a minimal pre-ferry leg (if any), else a full road route
local function buildRoute(fromAF, toAF, role, spawnZone, spawnPoint, terminalZ)
  local ferryChain = getFerryChain(fromAF, toAF)
  local ferryA = ferryChain and ferryChain[1] and ferryChain[1].A or nil
  local wps = {}

  -- 1) zone center hop (off-road) if not identical to spawn point
  if spawnZone then
    local addCenter = true
    if spawnPoint then
      local dx, dz = spawnPoint.x - spawnZone.x, spawnPoint.z - spawnZone.z
      if (dx*dx + dz*dz) < (50*50) then addCenter = false end
    end
    if addCenter then wps[#wps+1] = wpPoint({x=spawnZone.x, z=spawnZone.z}, 6.0, false) end
  end

  -- 2a) optional Start_WP_<From> (small zone centered on a road)
  local startWP = getStartWP(fromAF)
  if startWP then
    -- force a short off-road hop to Start_WP center
    wps[#wps+1] = wpPoint({x=startWP.x, z=startWP.z}, 6.0, false)
    -- then snap to road at Start_WP and continue on-road from there
    local sRoad = snapToRoad(startWP)
    wps[#wps+1] = wpPoint({x=sRoad.x, z=sRoad.z}, 8.0, true)
  end

  local roadStart
  if not startWP and spawnPoint then
    roadStart = snapToRoad(spawnPoint)
    local needHop = true
    if spawnZone then
      local dx, dz = (roadStart.x - spawnZone.x), (roadStart.z - spawnZone.z)
      if (dx*dx + dz*dz) < (30*30) then needHop = false end
    end
    if needHop then wps[#wps+1] = wpPoint({x=roadStart.x, z=roadStart.z}, 6.0, false) end
    wps[#wps+1] = wpPoint({x=roadStart.x, z=roadStart.z}, 8.0, true)
  end

  -- 3) numbered WPs (to ferry A if present; else all)
  local numbered = collectWaypoints(fromAF, toAF)
  if ferryA then
    local cut = _nearestWPToZone(numbered, ferryA) or 0
    for i=1, cut do wps[#wps+1] = wpPoint(snapToRoad(numbered[i]), 8.0, true) end
    wps[#wps+1] = wpPoint(snapToRoad(ferryA), 6.0, true)
    return wps
  else
    for _,z in ipairs(numbered) do wps[#wps+1] = wpPoint(snapToRoad(z), 8.0, true) end
  end

  -- 4) terminal / fallback
  if role=="AAA" then
    local destZ = terminalZ or getZone(fmt("AAA_%s_Deploy", fromAF)) or getZone(fromAF)
    if destZ then wps[#wps+1] = wpPoint(snapToRoad(destZ), 6.0, true) end
    else
    local fb = terminalZ or getZone(toAF)
    if fb then wps[#wps+1] = wpPoint(snapToRoad(fb), 6.0, true) end
  end

  -- de-dup adjacent points
  local out = {}
  local function tooClose(a,b) local dx=a.x-b.x; local dy=a.y-b.y; return (dx*dx+dy*dy) < (60*60) end
  for _,p in ipairs(wps) do if #out==0 or not tooClose(out[#out], p) then out[#out+1]=p end end
  return out
end

-- Full planned route for post-ferry continuation
local function buildPlannedRoute(fromAF, toAF, role, spawnZone, spawnPoint, terminalZ)
  local wps = {}

  if spawnZone then
    local addCenter = true
    if spawnPoint then
      local dx, dz = spawnPoint.x - spawnZone.x, spawnPoint.z - spawnZone.z
      if (dx*dx + dz*dz) < (50*50) then addCenter = false end
    end
    if addCenter then wps[#wps+1] = wpPoint({x=spawnZone.x, z=spawnZone.z}, 6.0, false) end
  end

    -- Optional Start_WP_<From>: off-road to it, then on-road from there
  local startWP = getStartWP(fromAF)
  if startWP then
    wps[#wps+1] = wpPoint({x=startWP.x, z=startWP.z}, 6.0, false)
    local sRoad = snapToRoad(startWP)
    wps[#wps+1] = wpPoint({x=sRoad.x, z=sRoad.z}, 8.0, true)
  end

  local roadStart
  if spawnPoint then
    roadStart = snapToRoad(spawnPoint)
    local needHop = true
    if spawnZone then
      local dx, dz = (roadStart.x - spawnZone.x), (roadStart.z - spawnZone.z)
      if (dx*dx + dz*dz) < (30*30) then needHop = false end
    end
    if needHop then wps[#wps+1] = wpPoint({x=roadStart.x, z=roadStart.z}, 6.0, false) end
    wps[#wps+1] = wpPoint({x=roadStart.x, z=roadStart.z}, 8.0, true)
  end

  for _,z in ipairs(collectWaypoints(fromAF, toAF)) do
    wps[#wps+1] = wpPoint(snapToRoad(z), 8.0, true)
  end

  if role=="AAA" then
    local destZ = terminalZ or getZone(fmt("AAA_%s_Deploy", fromAF)) or getZone(fromAF)
    if destZ then wps[#wps+1] = wpPoint(snapToRoad(destZ), 6.0, true) end
  else
    if terminalZ then
      wps[#wps+1] = wpPoint(snapToRoad(terminalZ), 6.0, true)
    else
    local fb = terminalZ or getZone(toAF)
      if fb then wps[#wps+1] = wpPoint(snapToRoad(fb), 6.0, true) end
    end
  end

  local out={} ; local function close(a,b) local dx=a.x-b.x; local dy=a.y-b.y; return (dx*dx+dy*dy)<(60*60) end
  for _,p in ipairs(wps) do if #out==0 or not close(out[#out], p) then out[#out+1]=p end end
  if #out==1 then local p=out[1]; out[#out+1]={x=p.x+10,y=p.y+10,action="On Road",speed=p.speed or 6.0,speed_locked=true,type="Turning Point",ETA=0,ETA_locked=false} end
  return out
end

---------------------------------------------------------------------
-- Route assign / watchdog
---------------------------------------------------------------------
function assignRoute(group, wps)
  if not group or not group:isExist() or not wps or #wps == 0 then return end

  -- ensure at least 2 points (1-point routes can be ignored by AI)
  if #wps == 1 then
    local p = wps[1]
    wps[2] = {
      x = p.x + 20, y = p.y + 20, alt = p.alt or 0, alt_type = "BARO",
      action = "On Road", speed = p.speed or 6.0, speed_locked = true,
      type = "Turning Point", ETA = 0, ETA_locked = false
    }
  end

  -- nudge the first point out if it's on top of the unit
  local u = group:getUnit(1)
  if u and u:isExist() then
    local p0 = u:getPoint()
    local function d2(a,bx,by) local dx=a.x-bx; local dz=a.y-by; return dx*dx+dz*dz end
    if d2(wps[1], p0.x, p0.z) < (30*30) then
      local t = wps[2]
      local vx, vy = (t.x - p0.x), (t.y - p0.z)
      local len = math.max(1, math.sqrt(vx*vx + vy*vy))
      wps[1].x = p0.x + (vx/len) * 60
      wps[1].y = p0.z + (vy/len) * 60
      wps[1].alt = (land and land.getHeight) and land.getHeight({x=wps[1].x, y=wps[1].y}) or 0
    end
  end

  local route = { points = wps, routeRelativeTOT = false }
  local mission = {
    id = 'Mission',
    params = {
      route = route,
      task  = { id = 'ComboTask', params = { tasks = {} } }
    }
  }

  local gname = group:getName()
  GROUND._lastRoute = GROUND._lastRoute or {}
  GROUND._lastRoute[gname] = route

  local ctrl = group:getController()
  if not ctrl then return end

  -- ensure AI is on, then apply the mission twice (some builds drop the first setTask)
  pcall(function() ctrl:setOnOff(true) end)
  pcall(function() ctrl:setTask(mission) end)
  timer.scheduleFunction(function()
    if group and group:isExist() then pcall(function() ctrl:setTask(mission) end) end
    return nil
  end, {}, now() + 1.0)
end

GROUND._lastPos   = GROUND._lastPos   or {}
GROUND._wdArmed   = GROUND._wdArmed   or false
GROUND._routeBuckets = GROUND._routeBuckets or {}

local function _pos2D(grp) if not grp or not grp:isExist() then return nil end local u=grp:getUnit(1); if not u then return nil end local p=u:getPoint(); return {x=p.x,z=p.z} end
local function _dist(a,b) local dx=a.x-b.x; local dz=a.z-b.z; return math.sqrt(dx*dx+dz*dz) end

-- Kick long-stalled groups and keep last-pos heartbeat
-- Kick long-stalled groups and keep last-pos heartbeat
local function _watchdog()
  for routeKey, members in pairs(GROUND._routeBuckets) do
    for gName,_ in pairs(members) do
      local g = Group.getByName(gName)
      if g and g:isExist() then
        local p = _pos2D(g)
        if p then
          local rec = GROUND._lastPos[gName]
          if not rec then
            GROUND._lastPos[gName] = { p=p, t=now() }
          else
            local dt = now() - rec.t
            if dt > 480 then  -- late kick (previously 8 min)
              if _dist(p, rec.p) < 200 then
                local ctrl  = g:getController()
                local route = GROUND._lastRoute and GROUND._lastRoute[gName]
                if ctrl and route then
                  pcall(function()
                    ctrl:setTask({
                      id='Mission',
                      params = { route = route, task = { id='ComboTask', params={tasks={}} } }
                    })
                  end)
                end
              end
              GROUND._lastPos[gName] = { p=p, t=now() }
            end
          end
        end
      end
    end
  end
  return now() + 120
end

-- Seed heartbeat + early stuck checks (kick, then refund+despawn if still stuck)
local function _seedWatchdogFor(grp)
  local name = grp and grp:getName()
  if name then GROUND._lastPos[name] = { p=_pos2D(grp) or {x=0,z=0}, t=now() } end
  if not GROUND._wdArmed then
    GROUND._wdArmed = true
    timer.scheduleFunction(function() return _watchdog() end, {}, now()+120)
  end
  if not name then return end

  -- helper: find this group's routeKey (so we can parse fromAF/role for refund)
  local function findRouteKeyFor(gname)
    for rk, members in pairs(GROUND._routeBuckets or {}) do
      if members[gname] then return rk end
    end
    return nil
  end

  -- Early kick ~20s after spawn if we haven't moved 25 m
  timer.scheduleFunction(function()
    local g = Group.getByName(name)
    if not (g and g:isExist()) then return nil end
    local rec = GROUND._lastPos[name]; local p = _pos2D(g)
    if not (rec and p) then return nil end

    if _dist(p, rec.p) < 25 then
      local ctrl  = g:getController()
      local route = GROUND._lastRoute and GROUND._lastRoute[name]
      if ctrl and route then
        pcall(function() ctrl:setOnOff(true) end)
        pcall(function()
          ctrl:setTask({
            id='Mission',
            params = { route = route, task = { id='ComboTask', params={tasks={}} } }
          })
        end)
      end

      -- If still stuck ~25s later: refund & despawn
      timer.scheduleFunction(function()
        local g2 = Group.getByName(name)
        if not (g2 and g2:isExist()) then return nil end
        local rec2 = GROUND._lastPos[name]; local p2 = _pos2D(g2)
        if not (rec2 and p2) then return nil end
        if _dist(p2, rec2.p) < 25 then
          -- Parse routeKey: "SIDE:from->to:ROLE"
          local rk = findRouteKeyFor(name)
          local fromAF, role
          if rk then
            local _, tail = rk:match("^([^:]+):(.*)$")
            if tail then fromAF, _, role = tail:match("^(.*)%-%>(.*):([^:]+)$") end
          end
          -- Refund economy (if we can resolve role & cost)
          local cost = role and CONFIG and CONFIG.GROUND and CONFIG.GROUND.COST and CONFIG.GROUND.COST[role]
          if fromAF and STATE and STATE.add and type(cost)=="table" then
            if cost.mp   then pcall(function() STATE.add(fromAF, "mp",   cost.mp)   end) end
            if cost.fuel then pcall(function() STATE.add(fromAF, "fuel", cost.fuel) end) end
            if cost.ammo then pcall(function() STATE.add(fromAF, "ammo", cost.ammo) end) end
          end
          -- Clean up registry & despawn
          if rk and GROUND._routeBuckets and GROUND._routeBuckets[rk] then
            GROUND._routeBuckets[rk][name] = nil
          end
          GROUND._lastPos[name] = nil
          if GROUND._lastRoute then GROUND._lastRoute[name] = nil end
          if GROUND._nav       then GROUND._nav[name]       = nil end
          pcall(function() g2:destroy() end)
          info(("[GROUND] %s stuck on spawn; despawned and refunded."):format(name))  -- <-- fixed
        end
        return nil
      end, {}, now()+25)
    end
    return nil
  end, {}, now()+20)
end

---------------------------------------------------------------------
-- Global cap & lifecycle
---------------------------------------------------------------------
local GLOBAL_MAX = (CONFIG and CONFIG.GROUND and CONFIG.GROUND.MAX_ACTIVE_GROUPS) or 5
local function _alive(grp) return grp and grp.isExist and grp:isExist() and grp:getSize() and grp:getSize()>0 end
local function _bucket(key) GROUND._routeBuckets[key] = GROUND._routeBuckets[key] or {}; return GROUND._routeBuckets[key] end
local function _aliveCountAll()
  local c=0
  for _,members in pairs(GROUND._routeBuckets) do
    for gName,_ in pairs(members) do
      local g=Group.getByName(gName)
      if _alive(g) then c=c+1 else members[gName]=nil end
    end
  end
  return c
end
local function canSpawnGlobal() return _aliveCountAll() < GLOBAL_MAX end
local function registerSpawn(key, name) _bucket(key)[name] = true end

local function countAlive(group)
  if not group or not group:isExist() then return 0,0 end
  local units = group:getUnits(); local t,a=0,0
  for _,u in ipairs(units) do t=t+1; if u and u:isExist() and u:getLife()>0 then a=a+1 end end
  return a,t
end

local function schedule(fn, delay) return timer.scheduleFunction(function() local ok,ret=pcall(fn); if not ok then env.info("[GROUND] timer error: "..tostring(ret)) end return nil end, {}, now()+delay) end

local function trackAndAutokill(group, role)
  if not (group and group:isExist()) then return end
  local gName = group:getName()
  timer.scheduleFunction(function()
    local g = gName and Group.getByName(gName) or nil
    if not g or not g:isExist() then return nil end
    local alive,total = countAlive(g)
    if total>0 then
      local loss = (total-alive)/total
      if loss>=0.70 then
        say(fmt("%s hit 70%% losses (%d/%d). Destroying in 5 min...", role, total-alive, total), 8)
        schedule(function() local g2=Group.getByName(gName); if g2 and g2:isExist() then pcall(function() g2:destroy() end) end end, 300)
        return nil
      end
    end
    return now()+120
  end, {}, now()+120)
end

---------------------------------------------------------------------
-- Spawning primitives & destination tasks
---------------------------------------------------------------------
local function spawnSingleVehicle(sideStr, unitType, point, heading, skill, fromAF)
  local cty = countryIdFor(sideStr, fromAF)
  local _, sName = coalitionSide(sideStr)
  local gName = fmt("GRD_%s_%s_%06d", sName, unitType, math.random(999999))
  local tpl = {
    visible=false, lateActivation=false, tasks={}, task="Ground Nothing",
    route={ points={} },
    units={{ name=gName.."_1", type=unitType, skill=skill or "Average", x=point.x, y=point.z, heading=heading or (math.random()*2*math.pi) }},
    name=gName
  }
  return coalition.addGroup(cty, Group.Category.GROUND, tpl)
end

local function _controller(g) return g and g.isExist and g:isExist() and g:getController() or nil end

local function taskSearchAndEngageFor1h(group, center, radius)
  local ctrl=_controller(group); if not ctrl or not center then return end
  ctrl:setTask({
    id='ComboTask',
    params={ tasks={
      { id='EngageTargetsInZone', params={ targetTypes={"All"}, priority=0, zone={ point={x=center.x,y=0,z=center.z}, radius=radius or 1500 } } },
      { id='WrappedAction', params={ action={ id='StopRoute', params={} } } }
    } }
  })
end

local function taskArtilleryFireAtPointFor1h(group, point)
  local ctrl=_controller(group); if not ctrl or not point then return end
  local t0,dur=now(),3600
  timer.scheduleFunction(function()
    if not group or not group:isExist() then return nil end
    if now()-t0>=dur then return nil end
    pcall(function() ctrl:pushTask({ id='FireAtPoint', params={ point={x=point.x, y=point.y or 0, z=point.z}, radius=50 } }) end)
    return now()+60
  end, {}, now()+5)
end

function waitUntilInZoneThen(group, zone, fn)
  if not group or not group:isExist() or not zone then return end
  timer.scheduleFunction(function()
    if not group or not group:isExist() then return nil end
    local u=group:getUnit(1); if not (u and u:isExist()) then return now()+10 end
    local p=u:getPoint(); local dx,dz=p.x-zone.x, p.z-zone.z
    local within=(dx*dx+dz*dz)<=((zone.radius or 100)^2)
    if within then fn(group); return nil end
    return now()+10
  end, {}, now()+5)
end

local function routeToFinalAirfieldAndHold(group, toAF)
    local z = getZone(toAF)
  if not (group and group:isExist() and z) then return end
  assignRoute(group, { wpPoint({x=z.x,z=z.z}, 6.0, true) })
end

-- Despawn group when the airfield they hold flips coalition
local function despawnOnFlip(group, holdAF, sideStr)
  local gName = group and group:getName()
  if not gName then return end
  timer.scheduleFunction(function()
    local g = Group.getByName(gName)
    if not g or not g:isExist() then return nil end
    local owner = ownerSideStr(holdAF)
    if owner and owner ~= sideStr then
      say(fmt("%s flipped. Despawning ground holder at %s.", holdAF, holdAF), 6)
      pcall(function() g:destroy() end)
      return nil
    end
    return now() + 30
  end, {}, now() + 30)
end

---------------------------------------------------------------------
-- AAA: scatter & transform (truck -> AAA site)
---------------------------------------------------------------------
local function scatterGroup(group, seconds)
  if not group or not group:isExist() then return end
  local ctrl=group:getController()
  if ctrl and AI and AI.Option and AI.Option.Ground then
    pcall(function() ctrl:setOption(AI.Option.Ground.id.DISPERSION_ON_ATTACK, true) end)
  end
  -- let it sit “unpacked” for a few seconds
  schedule(function() end, seconds or 15)
end

local function _jitterAround(x, z, rmin, rmax)
  local r = math.random()*(rmax - rmin) + rmin
  local a = math.random()*math.pi*2
  return x + math.cos(a)*r, z + math.sin(a)*r
end

local function transformAAA(group, sideStr, deployZone, fromAF)
  if not group or not group:isExist() then return end
  local u = group:getUnit(1); if not u then return end
  local p = u:getPoint()

  local sx, sz
  if deployZone then
    sx, sz = _jitterAround(deployZone.x, deployZone.z, 12, math.max(25, (deployZone.radius or 40) * 0.35))
  else
    sx, sz = _jitterAround(p.x, p.z, 12, 25)
  end

  pcall(function() group:destroy() end)

  local aaTypes = unitTypesFor(sideStr, "AAA", "AAA")
  local typeToUse = pick(aaTypes)
  if not typeToUse then info("AAA transform failed: no AAA types for "..tostring(sideStr)); return end

  local newG = spawnSingleVehicle(sideStr, typeToUse, { x=sx, y=0, z=sz }, nil, "Good", fromAF)
  if newG then
    armUp(newG:getController())
    say("AAA site deployed.", 6)
    -- Optional: request resupply tracking for AAA (TRANSPORT module must implement this)
    if TRANSPORT and TRANSPORT.requestResupplyAAA then
      pcall(function() TRANSPORT.requestResupplyAAA{ group=newG, from=fromAF, side=sideStr, threshold=0.20 } end)
    end
  end
end

---------------------------------------------------------------------
-- Role spawner (spawns ONE group)
---------------------------------------------------------------------
-- Role spawner (spawns ONE group)
local function spawnRole(fromAF, toAF, sideStr, role)
  if not canSpawnGlobal() then info("Global ground cap reached; skip spawn.") return nil, "globalcap" end

  local spawnZ, terminalZ = findRoleZones(role, fromAF, toAF)
  local routeKey = fmt("%s:%s->%s:%s", sideStr, fromAF, toAF, role)
  if not spawnZ then info(fmt("%s: missing spawn zone %s_%s_Spawn", role, role, fromAF)); return nil, "no spawn" end
  local ownerStr = ownerSideStr(fromAF)
  if ownerStr and ownerStr ~= sideStr then
    info(fmt("Ownership mismatch: %s is %s; skip %s %s.", fromAF, ownerStr, sideStr, role))
    return nil, "owner"
  end

  -- Only spawn at active airfields/fronts
  if role == "AAA" then
    if not (TERRAIN and TERRAIN.isAirfieldActive and TERRAIN.isAirfieldActive(fromAF)) then
      info("AAA spawn aborted: inactive AF " .. tostring(fromAF)); return nil, "inactive"
    end
  else
    if not isFrontActive(fromAF, toAF) then
      info(fmt("%s spawn aborted: front not active %s->%s", role, fromAF, toAF)); return nil, "front"
    end
  end

  local cost = CONFIG and CONFIG.GROUND and CONFIG.GROUND.COST and CONFIG.GROUND.COST[role]
  if cost and not canAfford(fromAF, sideStr, cost) then
    say(fmt("%s at %s refused: insufficient resources.", role, fromAF), 6); return nil, "econ"
  end

  local unitList = (role == "AAA") and unitTypesFor(sideStr, role, "TRUCK") or unitTypesFor(sideStr, role)
  local unitType = pick(unitList); if not unitType then info(fmt("%s: no unit types for %s", role, sideStr)); return nil, "types" end

  -- deconflicted spiral spawn inside spawn zone
  local spawnPoint = (function()
    GROUND._spawnSeq = GROUND._spawnSeq or {}
    local key = fmt("%s|%s|%s", role, fromAF, sideStr)
    local idx = (GROUND._spawnSeq[key] or 0) + 1; GROUND._spawnSeq[key] = idx
    local R = math.max(20, math.min(spawnZ.radius or 60, 120))
    local ang = idx * 2.3999632297; local rad = R * math.sqrt((idx % 25) / 25)
    return { x = spawnZ.x + math.cos(ang) * rad, y = 0, z = spawnZ.z + math.sin(ang) * rad }
  end)()

  local grp = spawnSingleVehicle(sideStr, unitType, spawnPoint, nil, "Average", fromAF)
  if not grp then return nil, "spawn failed" end
  registerSpawn(routeKey, grp:getName())

  local first = buildRoute(fromAF, toAF, role, spawnZ, spawnPoint, terminalZ)
    info(string.format("Assigned %d WPs to %s %s %s->%s", #first, sideStr, role, fromAF, toAF))
    assignRoute(grp, first)

  -- ROE/ALARM: ARTILLERY should not fire until at FOP/ATTACK
  if role ~= "ARTILLERY" then armUp(grp:getController()) end

  -- Planned route + optional ferry chain tracking
  STATE = STATE or {}; STATE.ROUTES = STATE.ROUTES or {}; STATE.FERRY_CHAINS = STATE.FERRY_CHAINS or {}
  local planned = buildPlannedRoute(fromAF, toAF, role, spawnZ, spawnPoint, terminalZ)
  STATE.ROUTES[grp:getName()] = { points = planned }
  local chain = getFerryChain(fromAF, toAF)
  if chain then STATE.FERRY_CHAINS[grp:getName()] = chain; info(string.format("Saved ferry chain (%d segs) for %s", #chain, grp:getName())) end
  if FERRY and FERRY.track then pcall(function() FERRY.track(grp) end) end

  -- Stepwise driving to ferry A if a chain exists; else plain route
  local numbered = collectWaypoints(fromAF, toAF)
  if chain and numbered and #numbered > 0 then
    local ferryA = chain[1].A
    local cut = _nearestWPToZone(numbered, ferryA) or 0
    local seq = {}; for i = 1, cut do seq[#seq + 1] = numbered[i] end; seq[#seq + 1] = ferryA
    GROUND._nav = GROUND._nav or {}
    GROUND._nav[grp:getName()] = { idx = 1, list = seq, from = fromAF, to = toAF }
    local function step()
      local rec = GROUND._nav[grp:getName()]; if not rec or not (grp and grp:isExist()) then return end
      local idx = rec.idx; if idx > #rec.list then return end
      local target = rec.list[idx]
      timer.scheduleFunction(function()
        routeToZoneOnRoad(grp, target, fromAF)
        waitUntilInZoneThen(grp, target, function()
          local me = GROUND._nav[grp:getName()]; if not me then return end; me.idx = me.idx + 1; step()
        end)
      end, {}, now() + orderDelay(0.25, 0.8))
    end
    step()
  else
    local wps = buildRoute(fromAF, toAF, role, spawnZ, spawnPoint, terminalZ)
    timer.scheduleFunction(function() assignRoute(grp, wps) end, {}, now() + orderDelay())
  end
  _seedWatchdogFor(grp)

  -- double “kick” to ensure movement
  timer.scheduleFunction(function()
    if grp and grp:isExist() then pcall(function()
      local c = grp:getController(); if c then c:setOnOff(true); c:setTask({ id='Mission', params={ route = GROUND._lastRoute[grp:getName()] } }) end
    end) end
    return nil
  end, {}, now() + 0.5)
  timer.scheduleFunction(function()
    if grp and grp:isExist() then pcall(function()
      local c = grp:getController(); if c then c:setOnOff(true); c:setTask({ id='Mission', params={ route = GROUND._lastRoute[grp:getName()] } }) end
    end) end
    return nil
  end, {}, now() + 5)

  -- role behaviors
  if role == "ARTILLERY" then
    local dest = terminalZ or getZone(fmt("ARTILLERY_%s_FOP", toAF)) or getZone(toAF)
    if dest then
      waitUntilInZoneThen(grp, dest, function(g)
        local ctrl = g and g:getController(); if ctrl then armUp(ctrl) end
        taskArtilleryFireAtPointFor1h(g, { x = dest.x, z = dest.z })
        schedule(function() routeToFinalAirfieldAndHold(g, toAF) end, 3600)
        schedule(function() despawnOnFlip(g, toAF, sideStr) end, 3610)
      end)
    end
  elseif role == "TANK" then
    local dest = terminalZ or getZone(toAF)
    if dest then
      waitUntilInZoneThen(grp, dest, function(g)
        taskSearchAndEngageFor1h(g, { x = dest.x, z = dest.z }, dest.radius or 800)
        schedule(function() routeToFinalAirfieldAndHold(g, toAF) end, 3600)
        schedule(function() despawnOnFlip(g, toAF, sideStr) end, 3610)
      end)
    end
  elseif role == "AAA" then
    local dest = terminalZ or getZone(fmt("AAA_%s_Deploy", fromAF)) or getZone(fromAF)
    if dest then
      waitUntilInZoneThen(grp, dest, function(g)
        local tdelay = math.random(10, 20)
        scatterGroup(g, tdelay)
        schedule(function() transformAAA(g, sideStr, dest, fromAF) end, tdelay + 1)
      end)
    end
  end

  if cost then debit(fromAF, sideStr, cost) end
  trackAndAutokill(grp, role)
  return grp
end

---------------------------------------------------------------------
-- Sequenced waves per route (AAA -> TANK -> ARTILLERY, 20 min gaps)
---------------------------------------------------------------------
GROUND._sequencers = GROUND._sequencers or {}
local function _seqKey(fromAF,toAF,sideStr) return fmt("%s:%s->%s", sideStr, fromAF, toAF) end

local function _sequenceForRoute()
  local seq = (CONFIG and CONFIG.GROUND and CONFIG.GROUND.SEQUENCE) or { "AAA","TANK","ARTILLERY" }
  local sec = (CONFIG and CONFIG.GROUND and CONFIG.GROUND.SEQ_DELAY_SEC)
  if sec and sec > 0 then return seq, sec, true end
  local min = (CONFIG and CONFIG.GROUND and CONFIG.GROUND.SEQ_DELAY_MIN) or 20
  return seq, min * 60, false
end

local function _stepSequencer(fromAF, toAF, sideStr)
  local key = _seqKey(fromAF,toAF,sideStr)
  local rec = GROUND._sequencers[key]; if not rec then return end
  if rec.stop then return end

  local seq, delaySeconds = _sequenceForRoute()
  rec.idx = ((rec.idx or 0) % #seq) + 1
  local role = seq[rec.idx]

  local allowed = (role=="AAA") and ((TERRAIN and TERRAIN.isAirfieldActive and TERRAIN.isAirfieldActive(fromAF)) or isFrontActive(fromAF, toAF))
                              or isFrontActive(fromAF, toAF)
  if allowed and canSpawnGlobal() then
    local ok,err = spawnRole(fromAF, toAF, sideStr, role)
    if ok then
      say(string.format("%s %s spawned (sequenced): %s -> %s", sideStr, role, fromAF, toAF), 5)
    else
      info(string.format("Sequencer spawn failed: %s %s %s->%s (%s)", sideStr, role, fromAF, toAF, tostring(err)))
    end
  else
    info(string.format("Sequencer: skip (allowed=%s, cap=%s)", tostring(allowed), tostring(canSpawnGlobal())))
  end

  rec.timer = timer.scheduleFunction(function()
    _stepSequencer(fromAF, toAF, sideStr)
    return nil
  end, {}, now() + delaySeconds)
end

local function _ensureSequencer(fromAF, toAF, sideStr)
  local key = _seqKey(fromAF,toAF,sideStr)
  local rec = GROUND._sequencers[key]
  if rec and rec.timer then return end
  GROUND._sequencers[key] = { idx = 0, stop = false, timer = nil }

  local splay = (CONFIG and CONFIG.GROUND and CONFIG.GROUND.ROUTE_STAGGER_SEC) or 0
  GROUND._startCount = (GROUND._startCount or 0) + 1
  local offset = 1.0 + (splay * (GROUND._startCount - 1))

  timer.scheduleFunction(function()
    _stepSequencer(fromAF, toAF, sideStr)
    return nil
  end, {}, now() + offset)
end

---------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------
-- Starts/ensures a SEQUENCED wave for the given route & sides.
-- One group at a time per route/side, 20 min gaps, AAA -> TANK -> ARTILLERY.
function GROUND.requestWave(opts)
  opts = opts or {}
  local fromAF, toAF = opts.from, opts.to
  local sideStrs = opts.sides or { "BLUE", "RED" }
  if not fromAF or not toAF then say("requestWave missing from/to.", 8); return end

  for _,sideStr in ipairs(sideStrs) do
    _ensureSequencer(fromAF, toAF, sideStr)
  end
end

-- Auto across all active fronts (uses same sequenced logic)
function GROUND.requestContestedWave(opts)
  opts = opts or {}
  local sideStrs = opts.sides or { "BLUE", "RED" }

  -- 1) Get activePairs from TERRAIN (function or table), or fallbacks
  local activePairs
  if TERRAIN and TERRAIN.fronts and TERRAIN.fronts.activePairs ~= nil then
    if type(TERRAIN.fronts.activePairs) == "function" then
      activePairs = TERRAIN.fronts.activePairs()
    else
      activePairs = TERRAIN.fronts.activePairs
    end
  end
  if not activePairs and TERRAIN and TERRAIN.getActiveFrontPairs then
    activePairs = TERRAIN.getActiveFrontPairs()
  end
  if not activePairs and CONFIG and CONFIG.GROUND and CONFIG.GROUND.DEFAULT_FRONT_PAIRS then
    activePairs = CONFIG.GROUND.DEFAULT_FRONT_PAIRS
  end
  activePairs = activePairs or {}

  -- 2) Normalize map→array if needed
  if type(activePairs) == "table" and activePairs[1] == nil then
    local arr = {}
    for _,v in pairs(activePairs) do arr[#arr+1] = v end
    activePairs = arr
  end

  if #activePairs == 0 then
    info("No active front pairs found."); return
  end

  -- 3) Start a sequencer for each front/side
  for _,pr in ipairs(activePairs) do
    local a = pr.from or pr[1]
    local b = pr.to   or pr[2]
    if a and b then
      for _,sideStr in ipairs(sideStrs) do
        _ensureSequencer(a, b, sideStr)  -- a -> b
        _ensureSequencer(b, a, sideStr)  -- b -> a  (this is the missing one)
      end
    end
  end
end

function GROUND.debugCounts()
  local function _alive(g) return g and g.isExist and g:isExist() and g:getSize() and g:getSize()>0 end
  local total = 0
  for key, members in pairs(GROUND._routeBuckets or {}) do
    local alive = 0
    for gName,_ in pairs(members) do
      if _alive(Group.getByName(gName)) then alive = alive + 1 end
    end
    env.info(string.format("[GROUND] route %s alive=%d", key, alive))
    total = total + alive
  end
  env.info(string.format("[GROUND] GLOBAL alive=%d cap=%d", total, (CONFIG and CONFIG.GROUND and CONFIG.GROUND.MAX_ACTIVE_GROUPS) or 5))
end

function GROUND.cleanupDead()
  for key, members in pairs(GROUND._routeBuckets or {}) do
    for gName,_ in pairs(members) do
      local g = Group.getByName(gName)
      if not (g and g:isExist()) then members[gName] = nil end
    end
  end
  env.info("[GROUND] cleaned up dead groups from buckets")
end

-- Initialize ground spawner + start waves
function GROUND.init(cfg)
  cfg = cfg or {}
  CONFIG       = CONFIG       or {}
  CONFIG.GROUND = CONFIG.GROUND or {}

  -- optional overrides from OPERATIONINIT/CONFIG
  if cfg.SEQ_DELAY_SEC      then CONFIG.GROUND.SEQ_DELAY_SEC      = cfg.SEQ_DELAY_SEC end
  if cfg.SEQ_DELAY_MIN      then CONFIG.GROUND.SEQ_DELAY_MIN      = cfg.SEQ_DELAY_MIN end
  if cfg.MAX_ACTIVE_GROUPS  then CONFIG.GROUND.MAX_ACTIVE_GROUPS  = cfg.MAX_ACTIVE_GROUPS end
  if cfg.IGNORE_OWNERSHIP ~= nil then CONFIG.GROUND.IGNORE_OWNERSHIP = cfg.IGNORE_OWNERSHIP end
  if cfg.IGNORE_ECON     ~= nil then CONFIG.GROUND.IGNORE_ECON      = cfg.IGNORE_ECON end

  local sides = cfg.sides or {"BLUE","RED"}

  -- Start routes
  if cfg.routes and #cfg.routes > 0 then
    for _,r in ipairs(cfg.routes) do
      local from = r.from or r[1]; local to = r.to or r[2]
      GROUND.requestWave{ from = from, to = to, sides = sides }
    end
  else
    -- default: auto across active fronts
    GROUND.requestContestedWave{ sides = sides }
  end

  env.info("[GROUND] init complete.")
end


pcall(function() trigger.action.outText("GROUND.lua LOADED...).", 5) end)
return GROUND