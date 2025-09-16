-- TRANSPORT.lua — Airfield/AAA resupply (trucks or helicopters) for Operation Cold-War Breach
-- No MIST/MOOSE. Works with STATE.lua and TERRAIN.lua if present. Safe fallbacks if they aren’t.

TRANSPORT = TRANSPORT or {}

local function say(t, d) trigger.action.outText("[TRANSPORT] "..tostring(t), d or 5) end
local function now() return timer.getTime() end
local function info(t) env.info("[TRANSPORT] "..tostring(t)) end
local function fmt(...) return string.format(...) end
local function pick(t) if type(t)=="table" and #t>0 then return t[math.random(#t)] end end

---------------------------------------------------------------------
-- Config (all knobs come from CONFIG.lua, with sane fallbacks)
---------------------------------------------------------------------
TRANSPORT.cfg = {
  scan_interval_sec       = (CONFIG and CONFIG.TRANSPORT and CONFIG.TRANSPORT.scan_interval_sec) or 60,

  -- Range / radii (meters)
  TRUCK_MAX_RANGE_M       = (CONFIG and CONFIG.TRANSPORT and CONFIG.TRANSPORT.TRUCK_MAX_RANGE_M) or 120000,
  ARRIVAL_RADIUS_TRUCK_M  = (CONFIG and CONFIG.TRANSPORT and CONFIG.TRANSPORT.ARRIVAL_RADIUS_TRUCK_M) or 30,   -- ~100 ft
  ARRIVAL_RADIUS_HELO_M   = (CONFIG and CONFIG.TRANSPORT and CONFIG.TRANSPORT.ARRIVAL_RADIUS_HELO_M) or 350,

  -- Composition & failure
  TRUCK_CONVOY_COUNT      = (CONFIG and CONFIG.TRANSPORT and CONFIG.TRANSPORT.TRUCK_CONVOY_COUNT) or 10,
  HELO_FLIGHT_COUNT       = (CONFIG and CONFIG.TRANSPORT and CONFIG.TRANSPORT.HELO_FLIGHT_COUNT) or 2,
  FAILURE_LOSS_FRACTION   = (CONFIG and CONFIG.TRANSPORT and CONFIG.TRANSPORT.FAILURE_LOSS_FRACTION) or 0.70,

  -- Timers
  TRUCK_DWELL_SEC         = (CONFIG and CONFIG.TRANSPORT and CONFIG.TRANSPORT.TRUCK_DWELL_SEC) or 120,  -- 2 min
  TRUCK_FAIL_RETRY_SEC    = (CONFIG and CONFIG.TRANSPORT and CONFIG.TRANSPORT.TRUCK_FAIL_RETRY_SEC) or 3600,
  HELO_SHUTDOWN_DWELL_SEC = (CONFIG and CONFIG.TRANSPORT and CONFIG.TRANSPORT.HELO_SHUTDOWN_DWELL_SEC) or 300,  -- 5 min
  HELO_FAIL_RETRY_SEC     = (CONFIG and CONFIG.TRANSPORT and CONFIG.TRANSPORT.HELO_FAIL_RETRY_SEC) or 3600,

  HUB_THRESHOLD_FRACTION  = (CONFIG and CONFIG.TRANSPORT and CONFIG.TRANSPORT.HUB_THRESHOLD_FRACTION) or 0.50,

  -- Delivery amounts per *dispatch*
  DELIVER_TRUCK = (CONFIG and CONFIG.TRANSPORT and CONFIG.TRANSPORT.DELIVER_TRUCK) or { mp=10,  ammo=20,  fuel=100  },
  DELIVER_HELO  = (CONFIG and CONFIG.TRANSPORT and CONFIG.TRANSPORT.DELIVER_HELO ) or { mp=30,  ammo=50,  fuel=500  },

  -- AAA replenish trigger
  AAA_THRESHOLD_FRAC      = (CONFIG and CONFIG.GROUND and CONFIG.GROUND.AAA_REPLENISH_THRESHOLD) or 0.20,

  debug                   = (CONFIG and CONFIG.TRANSPORT and CONFIG.TRANSPORT.debug) or false,
}

local function dbg(t) if TRANSPORT.cfg.debug then trigger.action.outText("[TRANSPORT] "..tostring(t), 6) end end

-- resource key translator (friendly → STATE keys)
local RES = { manpower="mp", ammo="ammo", fuel="fuel" }
local function resKey(k) return RES[k] or k end

---------------------------------------------------------------------
-- Helpers (zones, positions, distances, ownership)
---------------------------------------------------------------------
local function getZone(name)
  if not name then return nil end
  local z = trigger.misc.getZone(name)
  if z and z.point then return { name=name, x=z.point.x, y=0, z=z.point.z, r=z.radius or 1500 } end
  return nil
end

local function dist2D(a,b) local dx=a.x-b.x; local dz=a.z-b.z; return math.sqrt(dx*dx+dz*dz) end

local function airfieldPos(afName)
  if TERRAIN and TERRAIN.AIRFIELDS then
    local e = TERRAIN.AIRFIELDS[afName]
    if e and e.zone then local z = getZone(e.zone); if z then return {x=z.x,y=0,z=z.z}, z end end
  end
  local z = getZone(afName); if z then return {x=z.x,y=0,z=z.z}, z end
  return nil,nil
end

local function closestRoad(p)
  if not p then return nil end
  local v2={x=p.x,y=p.z}
  local ok=land and land.getClosestPointOnRoad and land.getClosestPointOnRoad(v2)
  if ok and ok.x and ok.y then return {x=ok.x,z=ok.y} end
  return {x=p.x,z=p.z}
end

local function countryFor(sideStr)
  if CONFIG and CONFIG.GROUND and CONFIG.GROUND.COUNTRY and CONFIG.GROUND.COUNTRY[sideStr] then
    return CONFIG.GROUND.COUNTRY[sideStr]
  end
  return (sideStr=="RED") and country.id.RUSSIA or country.id.USA
end

---------------------------------------------------------------------
-- Economy adapters (always translate keys)
---------------------------------------------------------------------
local function econ_get(af, res)
  local key = resKey(res)
  if STATE and STATE.get then return STATE.get(af, key) end
  return nil
end
local function econ_add(af, res, amt)
  local key = resKey(res)
  if STATE and STATE.give then return STATE.give(af, key, amt) end
  if STATE and STATE.add  then return STATE.add (af, key, amt) end
  return false
end
local function econ_take(af, res, amt)
  local key = resKey(res)
  if STATE and STATE.take then return STATE.take(af, key, amt) end
  if STATE and STATE.consume then return STATE.consume(af, key, amt) end
  return false
end
local function econ_cap(af, res)
  local key = resKey(res)
  if STATE and STATE.cap then return STATE.cap(af, key) end
  return nil
end

---------------------------------------------------------------------
-- Templates
---------------------------------------------------------------------
local function truckType(sideStr)
  if UNITS and UNITS.TRANSPORT and UNITS.TRANSPORT[sideStr] and UNITS.TRANSPORT[sideStr].TRUCK then
    return pick(UNITS.TRANSPORT[sideStr].TRUCK)
  end
  return (sideStr=="RED") and "Ural-4320T" or "M 818"
end

local function heloType(sideStr)
  if UNITS and UNITS.TRANSPORT and UNITS.TRANSPORT[sideStr] and UNITS.TRANSPORT[sideStr].HELO then
    return pick(UNITS.TRANSPORT[sideStr].HELO)
  end
  return (sideStr=="RED") and "Mi-8MT" or "CH-47Fbl1"
end

---------------------------------------------------------------------
-- Group helpers
---------------------------------------------------------------------
local function countAlive(group)
  if not group or not group:isExist() then return 0,0 end
  local units = group:getUnits() or {}
  local t,a=0,0
  for _,u in ipairs(units) do t=t+1; if u and u.isExist and u:isExist() and u:getLife()>0 then a=a+1 end end
  return a,t
end

local function assignRoute(group, wps)
  if not (group and group:isExist() and wps and #wps>0) then return end
  local route = { points = wps }
  local ctrl = group:getController()
  if ctrl then pcall(function() ctrl:setTask({ id='Mission', params={ route=route } }) end) end
end

local function wpTurn(x,z,onRoad,speed)
  return { x=x, y=z, action=(onRoad and "On Road" or "Off Road"),
           speed=speed or 8.0, speed_locked=true, type="Turning Point",
           ETA=0, ETA_locked=false }
end

---------------------------------------------------------------------
-- Truck convoys
---------------------------------------------------------------------
TRANSPORT._activeConvoys = TRANSPORT._activeConvoys or {} -- name -> rec
local function convoyKey(from,to,res) return fmt("%s->%s:%s", from, to, resKey(res)) end
local function convoyInProgress(from,to,res)
  local key = convoyKey(from,to,res)
  for name,rec in pairs(TRANSPORT._activeConvoys) do
    if rec.key==key and (rec.status=="enroute" or rec.status=="arrive" or rec.status=="success_wait") then return true end
    if rec.key==key and rec.status=="failed" and rec.retry_at and rec.retry_at>now() then return true end
  end
  return false
end

local function spawnTruckConvoy(sideStr, fromAF, toAF, res)
  local ctry = countryFor(sideStr)
  local startPos = select(1, airfieldPos(fromAF)); if not startPos then return nil end
  local destPos  = select(1, airfieldPos(toAF));   if not destPos   then return nil end

  local roadStart = closestRoad(startPos)
  local roadDest  = closestRoad(destPos)

  local gname = fmt("TR_%s_%s_%s_%06d", sideStr, fromAF, resKey(res), math.random(999999))
  local uType = truckType(sideStr)

  local units = {}
  local spacing = 8
  for i=1, TRANSPORT.cfg.TRUCK_CONVOY_COUNT do
    units[#units+1] = { name=gname.."_U"..i, type=uType, skill="Average",
                        x=roadStart.x+(i-1)*spacing, y=roadStart.z+(i-1)*spacing, heading=0 }
  end

  local tpl = {
    visible=false, lateActivation=false, tasks={}, task="Ground Nothing",
    route={ points = {
      wpTurn(roadStart.x, roadStart.z, true, 8.0),
      wpTurn(roadDest.x,  roadDest.z,  true, 8.0),
      wpTurn(destPos.x,   destPos.z,   false,5.0),
    }},
    units = units, name  = gname
  }

  local grp = coalition.addGroup(ctry, Group.Category.GROUND, tpl)
  if not grp then return nil end

  TRANSPORT._activeConvoys[gname] = {
    key=convoyKey(fromAF,toAF,res), groupName=gname, side=sideStr, res=resKey(res),
    from=fromAF, to=toAF, start_t=now(), dwell_t=0, status="enroute"
  }
  say(fmt("%s convoy (%s) departed %s → %s", sideStr, resKey(res), fromAF, toAF), 6)
  return grp
end

local function tickConvoys()
  for name, rec in pairs(TRANSPORT._activeConvoys) do
    local g = Group.getByName(name)
    if not g or not g:isExist() then
      if rec.status ~= "success" and rec.retry_at == nil then
        rec.status  = "failed"
        rec.retry_at = now() + TRANSPORT.cfg.TRUCK_FAIL_RETRY_SEC
        say(fmt("Convoy %s failed; retry in 60 min.", name), 6)
      end
    else
      local a,t = countAlive(g)
      if t>0 and (1 - a/t) >= TRANSPORT.cfg.FAILURE_LOSS_FRACTION and rec.status=="enroute" then
        say(fmt("Convoy %s suffered heavy losses; aborting.", name), 8)
        pcall(function() g:destroy() end)
        rec.status  = "failed"
        rec.retry_at = now() + TRANSPORT.cfg.TRUCK_FAIL_RETRY_SEC
      else
        local u = g:getUnit(1)
        if u and u:isExist() then
          local p = u:getPoint()
          local destPos = select(1, airfieldPos(rec.to))
          if destPos then
            local d = dist2D({x=p.x,z=p.z}, destPos)
            if d <= TRANSPORT.cfg.ARRIVAL_RADIUS_TRUCK_M then
              rec.dwell_t = rec.dwell_t + TRANSPORT.cfg.scan_interval_sec
              if rec.dwell_t >= TRANSPORT.cfg.TRUCK_DWELL_SEC then
                -- TRUCK delivery amounts are per-dispatch (not per-vehicle)
                local add = TRANSPORT.cfg.DELIVER_TRUCK
                econ_add(rec.to, "manpower", add.mp)
                econ_add(rec.to, "ammo",     add.ammo)
                econ_add(rec.to, "fuel",     add.fuel)
                say(fmt("Convoy %s delivered (+%d MP, +%d Ammo, +%d Fuel) to %s.",
                        name, add.mp, add.ammo, add.fuel, rec.to), 6)
                pcall(function() g:destroy() end)
                rec.status = "success"; rec.finished = now()
              end
            else rec.dwell_t = 0 end
          end
        end
      end
    end
  end
  return now() + TRANSPORT.cfg.scan_interval_sec
end

---------------------------------------------------------------------
-- Helicopter flights (cold start → fly → land → deliver → RTB → land → 5m → despawn)
---------------------------------------------------------------------
TRANSPORT._activeFlights = TRANSPORT._activeFlights or {} -- name -> rec

local function heloRoutePoints(fromPos, toPos, phase)
  if phase=="out" then
    return {
      { x=fromPos.x, y=fromPos.z, type="TakeOffParking", action="From Parking Area", speed=0, speed_locked=true, ETA=0, ETA_locked=false },
      { x=(fromPos.x+toPos.x)/2, y=(fromPos.z+toPos.z)/2, type="Turning Point", action="Turning Point", speed=55, speed_locked=true, ETA=0, ETA_locked=false },
      { x=toPos.x,   y=toPos.z,   type="Landing",        action="Landing",       speed=0,  speed_locked=true, ETA=0, ETA_locked=false },
    }
  else
    return {
      { x=toPos.x,   y=toPos.z,   type="TakeOffGround",  action="TakeOffGround",  speed=0,  speed_locked=true, ETA=0, ETA_locked=false },
      { x=(fromPos.x+toPos.x)/2, y=(fromPos.z+toPos.z)/2, type="Turning Point", action="Turning Point", speed=55, speed_locked=true, ETA=0, ETA_locked=false },
      { x=fromPos.x, y=fromPos.z, type="Landing",        action="Landing",       speed=0,  speed_locked=true, ETA=0, ETA_locked=false },
    }
  end
end

local function spawnHeloFlight(sideStr, fromAF, toAF, res)
  local ctry   = countryFor(sideStr)
  local fromPos= select(1, airfieldPos(fromAF)); if not fromPos then return nil end
  local toPos  = select(1, airfieldPos(toAF));   if not toPos   then return nil end

  local hType  = heloType(sideStr)
  local gname  = fmt("TH_%s_%s_%s_%06d", sideStr, fromAF, resKey(res), math.random(999999))
  local units  = {}
  local spacing= 20
  for i=1, TRANSPORT.cfg.HELO_FLIGHT_COUNT do
    units[#units+1] = { name=gname.."_U"..i, type=hType, skill="Average",
                        x=fromPos.x+(i-1)*spacing, y=fromPos.z+(i-1)*spacing, heading=0, payload={}, onboard_num=i }
  end

  local tpl = {
    visible=false, lateActivation=false, tasks={}, task="Transport",
    route={ points = heloRoutePoints(fromPos, toPos, "out") },
    units=units, name=gname
  }

  local grp = coalition.addGroup(ctry, Group.Category.HELICOPTER, tpl)
  if not grp then return nil end

  TRANSPORT._activeFlights[gname] = {
    groupName=gname, side=sideStr, res=resKey(res), from=fromAF, to=toAF,
    phase="out", landed=false, dwell_t=0, start_t=now(), status="enroute"
  }
  say(fmt("%s helo flight (%s) airborne %s → %s", sideStr, resKey(res), fromAF, toAF), 6)
  return grp
end

local function tickFlights()
  for name, rec in pairs(TRANSPORT._activeFlights) do
    local g = Group.getByName(name)
    if not g or not g:isExist() then
      if rec.status ~= "success" and rec.retry_at == nil then
        rec.status="failed"; rec.retry_at=now()+TRANSPORT.cfg.HELO_FAIL_RETRY_SEC
        say(fmt("Helo flight %s failed; retry in 60 min.", name), 6)
      end
    else
      local a,t = countAlive(g)
      if t>0 and (1 - a/t) >= TRANSPORT.cfg.FAILURE_LOSS_FRACTION and rec.status=="enroute" then
        say(fmt("Helo flight %s suffered heavy losses; aborting.", name), 8)
        pcall(function() g:destroy() end)
        rec.status="failed"; rec.retry_at=now()+TRANSPORT.cfg.HELO_FAIL_RETRY_SEC
      else
        local u = g:getUnit(1)
        if u and u:isExist() then
          local p = u:getPoint()
          local toPos   = select(1, airfieldPos(rec.to))
          local fromPos = select(1, airfieldPos(rec.from))
          if rec.phase=="out" and toPos then
            local d = dist2D({x=p.x,z=p.z}, toPos)
            if d <= TRANSPORT.cfg.ARRIVAL_RADIUS_HELO_M then
              rec.dwell_t = rec.dwell_t + TRANSPORT.cfg.scan_interval_sec
              if rec.dwell_t >= TRANSPORT.cfg.HELO_SHUTDOWN_DWELL_SEC then
                -- HELI delivery amounts are per-dispatch
                local add = TRANSPORT.cfg.DELIVER_HELO
                econ_add(rec.to, "manpower", add.mp)
                econ_add(rec.to, "ammo",     add.ammo)
                econ_add(rec.to, "fuel",     add.fuel)
                say(fmt("Helo flight %s delivered (+%d MP, +%d Ammo, +%d Fuel) to %s.",
                        name, add.mp, add.ammo, add.fuel, rec.to), 6)
                -- RTB
                rec.phase="rtb"; rec.dwell_t=0
                assignRoute(g, heloRoutePoints(fromPos, toPos, "back"))
              end
            else rec.dwell_t=0 end
          elseif rec.phase=="rtb" and fromPos then
            local d = dist2D({x=p.x,z=p.z}, fromPos)
            if d <= TRANSPORT.cfg.ARRIVAL_RADIUS_HELO_M then
              rec.dwell_t = rec.dwell_t + TRANSPORT.cfg.scan_interval_sec
              if rec.dwell_t >= TRANSPORT.cfg.HELO_SHUTDOWN_DWELL_SEC then
                pcall(function() g:destroy() end)
                rec.status="success"; rec.finished=now()
              end
            else rec.dwell_t=0 end
          end
        end
      end
    end
  end
  return now() + TRANSPORT.cfg.scan_interval_sec
end

---------------------------------------------------------------------
-- Auto scheduler (scan hubs → find needy AFs → dispatch)
---------------------------------------------------------------------
TRANSPORT._scannerArmed = TRANSPORT._scannerArmed or false

local function hubsFor(sideStr)
  local hubs={}
  if not (TERRAIN and TERRAIN.AIRFIELDS) then return hubs end
  for afName,e in pairs(TERRAIN.AIRFIELDS) do
    if e.owner == ((sideStr=="RED") and coalition.side.RED or coalition.side.BLUE) then
      local ok=true
      for _,r in ipairs({"manpower","ammo","fuel"}) do
        local v = econ_get(afName, r); local cap = econ_cap(afName, r) or 1
        if not v or (v/cap) < TRANSPORT.cfg.HUB_THRESHOLD_FRACTION then ok=false; break end
      end
      if ok then hubs[#hubs+1]=afName end
    end
  end
  return hubs
end

local function needyFor(sideStr)
  local out={}
  if not (TERRAIN and TERRAIN.AIRFIELDS) then return out end
  for afName,e in pairs(TERRAIN.AIRFIELDS) do
    if e.owner == ((sideStr=="RED") and coalition.side.RED or coalition.side.BLUE) then
      for _,r in ipairs({"manpower","ammo","fuel"}) do
        local v = econ_get(afName, r); local cap = econ_cap(afName, r) or 1
        if v and cap and v/cap < 0.30 then out[#out+1] = { af=afName, res=r } end -- below 30% needs help
      end
    end
  end
  return out
end

local function ensureDelivery(sideStr, fromAF, toAF, res)
  if not (fromAF and toAF and res) then return end
  if fromAF==toAF then return end
  if convoyInProgress(fromAF,toAF,res) then return end

  -- Decide truck vs helo by distance, then debit *at dispatch* (no refund on failure)
  local fromPos,toPos = select(1, airfieldPos(fromAF)), select(1, airfieldPos(toAF))
  if not (fromPos and toPos) then return end
  local d   = dist2D(fromPos, toPos)
  local mode= (d <= TRANSPORT.cfg.TRUCK_MAX_RANGE_M) and "TRUCK" or "HELO"

  local debitTbl = (mode=="TRUCK") and TRANSPORT.cfg.DELIVER_TRUCK or TRANSPORT.cfg.DELIVER_HELO
  -- only take what's actually available at source; if insufficient for any res, skip dispatch
  for k,v in pairs(debitTbl) do if (econ_get(fromAF, k) or 0) < v then return end end
  for k,v in pairs(debitTbl) do econ_take(fromAF, k, v) end

  if mode=="TRUCK" then
    local g = spawnTruckConvoy(sideStr, fromAF, toAF, res)
    if not g then for k,v in pairs(debitTbl) do econ_add(fromAF, k, v) end return end
  else
    local g = spawnHeloFlight (sideStr, fromAF, toAF, res)
    if not g then for k,v in pairs(debitTbl) do econ_add(fromAF, k, v) end return end
  end
end

local function pickHubFor(sideStr, dstAF)
  local dstPos = select(1, airfieldPos(dstAF)); if not dstPos then return nil end
  local best,bd=nil,1e18
  for _,h in ipairs(hubsFor(sideStr)) do
    local hp = select(1, airfieldPos(h))
    if hp then local d=dist2D({x=hp.x,z=hp.z},{x=dstPos.x,z=dstPos.z}); if d<bd then best,bd=h,d end end
  end
  return best,bd
end

local function autoScan()
  for _,sideStr in ipairs({"BLUE","RED"}) do
    local needs = needyFor(sideStr)
    for _,n in ipairs(needs) do
      local hub = pickHubFor(sideStr, n.af)
      if hub then ensureDelivery(sideStr, hub, n.af, n.res) end
    end
  end
  return now() + TRANSPORT.cfg.scan_interval_sec
end

---------------------------------------------------------------------
-- AAA resupply (ammo only) + alias for older call name
---------------------------------------------------------------------
TRANSPORT._aaaJobs = TRANSPORT._aaaJobs or {} -- key "side|x|z" -> rec

local function truckToPoint(sideStr, fromAF, toPoint)
  local ctry = countryFor(sideStr)
  local startPos = select(1, airfieldPos(fromAF)); if not startPos then return nil end
  local roadStart, roadDest = closestRoad(startPos), closestRoad(toPoint)
  local gname = fmt("AAAR_%s_%06d", sideStr, math.random(999999))
  local uType = truckType(sideStr)
  local tpl = {
    visible=false, lateActivation=false, tasks={}, task="Ground Nothing",
    route={ points = {
      wpTurn(roadStart.x, roadStart.z, true, 8.0),
      wpTurn(roadDest.x,  roadDest.z,  true, 8.0),
      wpTurn(toPoint.x,   toPoint.z,   false,5.0),
    }},
    units = { { name=gname.."_U1", type=uType, skill="Average", x=roadStart.x, y=roadStart.z, heading=0 } },
    name=gname
  }
  return coalition.addGroup(ctry, Group.Category.GROUND, tpl), gname
end

-- Call this when an AAA site drops below threshold
function TRANSPORT.requestAAAAmmo(sideStr, sitePoint, fromAF)
  if not (sideStr and sitePoint and fromAF) then return end
  local key = fmt("%s|%d|%d", sideStr, math.floor(sitePoint.x), math.floor(sitePoint.z))
  if TRANSPORT._aaaJobs[key] then return end
  local grp, name = truckToPoint(sideStr, fromAF, sitePoint); if not grp then return end
  TRANSPORT._aaaJobs[key] = { groupName=name, toPoint=sitePoint, start_t=now(), dwell_t=0, status="enroute" }
  say(fmt("AAA ammo truck dispatched from %s.", fromAF), 6)
end
-- Backwards-compatible alias (GROUND.lua may call this)
TRANSPORT.requestResupplyAAA = TRANSPORT.requestAAAAmmo

local function tickAAA()
  for key, rec in pairs(TRANSPORT._aaaJobs) do
    local g = Group.getByName(rec.groupName)
    if not g or not g:isExist() then TRANSPORT._aaaJobs[key]=nil
    else
      local u = g:getUnit(1)
      if u and u:isExist() then
        local p = u:getPoint()
        local d = dist2D({x=p.x,z=p.z}, {x=rec.toPoint.x,z=rec.toPoint.z})
        if d <= 50 then
          rec.dwell_t = rec.dwell_t + TRANSPORT.cfg.scan_interval_sec
          if rec.dwell_t >= 30 then
            pcall(function() g:destroy() end)
            TRANSPORT._aaaJobs[key]=nil
            say("AAA ammo truck delivered.", 5)
          end
        else rec.dwell_t=0 end
      end
    end
  end
  return now() + TRANSPORT.cfg.scan_interval_sec
end

---------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------
function TRANSPORT.init()
  if TRANSPORT._armed then return end
  TRANSPORT._armed = true
  timer.scheduleFunction(function() return tickConvoys() end, {}, now()+TRANSPORT.cfg.scan_interval_sec)
  timer.scheduleFunction(function() return tickFlights()  end, {}, now()+TRANSPORT.cfg.scan_interval_sec)
  timer.scheduleFunction(function() return autoScan()     end, {}, now()+TRANSPORT.cfg.scan_interval_sec)
  timer.scheduleFunction(function() return tickAAA()      end, {}, now()+TRANSPORT.cfg.scan_interval_sec)
  dbg("TRANSPORT initialized.")
end

-- Manual request (e.g., menus)
-- opts = { side="BLUE"/"RED", from="Bodo", to="Evenes", res="ammo"/"fuel"/"manpower" }
function TRANSPORT.request(opts)
  opts = opts or {}
  local side, from, to, res = opts.side or "BLUE", opts.from, opts.to, opts.res
  if not (from and to and res) then say("TRANSPORT.request missing params.", 8); return end
  ensureDelivery(side, from, to, res)
end

function TRANSPORT.setDebug(on) TRANSPORT.cfg.debug = not not on end

info("TRANSPORT.lua loaded.")
