-- SIDEMISSIONS.lua — Player-requested tasks (CAS, CAP, INTERCEPT, TRANSPORT)
-- Integrates with: AIR.lua, TRANSPORT.lua, TERRAIN.lua, MARK.lua, STATE.lua (optional)
-- No MIST/MOOSE required. Fully sandbox-safe (pcall around externals).

SIDEMISSIONS = SIDEMISSIONS or {}

local function now() return timer.getTime() end
local function say(t, d) trigger.action.outText("[MISSIONS] "..tostring(t), d or 6) end
local function log(t) if env and env.info then env.info("[SIDEMISSIONS] "..tostring(t)) end end

-- ---------------------------------------------------------------------------
-- Config (overridden by CONFIG.SIDEMISSIONS if present)
-- ---------------------------------------------------------------------------
SIDEMISSIONS.cfg = {
  MAX_MISSION_RANGE_M = (CONFIG and CONFIG.SIDEMISSIONS and CONFIG.SIDEMISSIONS.MAX_MISSION_RANGE_M) or 1852000, -- ≈1000 nm
  BUBBLE_RADIUS_M     = (CONFIG and CONFIG.SIDEMISSIONS and CONFIG.SIDEMISSIONS.BUBBLE_RADIUS_M) or 3000,
  AUTO_EXPIRE_MIN     = (CONFIG and CONFIG.SIDEMISSIONS and CONFIG.SIDEMISSIONS.AUTO_EXPIRE_MIN) or 45,
  SCORE_PER_KILL      = (CONFIG and CONFIG.SIDEMISSIONS and CONFIG.SIDEMISSIONS.SCORE_PER_KILL) or 5,
  INTERCEPT_RAID_SIZE = (CONFIG and CONFIG.SIDEMISSIONS and CONFIG.SIDEMISSIONS.INTERCEPT_RAID_SIZE) or 2,
  -- CAP patrol requirement: player must accumulate this many seconds inside bubble
  CAP_REQUIRED_SEC    = 20 * 60,
}

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
-- Return coalition.side.* for any object we might get from events (unit, weapon, static)
local function objCoalition(obj)
  if not (obj and obj.isExist and obj:isExist()) then return nil end

  -- If it's a weapon, try to get the launcher Unit
  if obj.getLauncher then
    local L = obj:getLauncher()
    if L and L.isExist and L:isExist() then obj = L end
  end

  -- Direct Unit method
  if obj.getCoalition then
    return obj:getCoalition()
  end

  -- Some objects expose a Group; try that
  if obj.getGroup then
    local g = obj:getGroup()
    if g and g.getCoalition then return g:getCoalition() end
  end

  -- Country fallback (e.g., StaticObject)
  if obj.getCountry and coalition.getCountryCoalition then
    local c = obj:getCountry()
    if c then return coalition.getCountryCoalition(c) end
  end

  return nil
end

local function getZone(name)
  local z = name and trigger.misc.getZone(name)
  return (z and z.point) and { name=name, x=z.point.x, z=z.point.z, r=z.radius or SIDEMISSIONS.cfg.BUBBLE_RADIUS_M } or nil
end

local function pointOfUnitName(unitName)
  local u = Unit.getByName(unitName)
  if not (u and u:isExist()) then return nil end
  local p = u:getPoint()
  return { x=p.x, y=p.y, z=p.z }
end

local function sideStr(coal)
  return (coal==coalition.side.RED) and "RED" or "BLUE"
end

local function playerSide(unitName)
  local u = Unit.getByName(unitName)
  return (u and u:isExist()) and sideStr(u:getCoalition()) or nil
end

local function dist2D(ax,az,bx,bz)
  local dx, dz = ax-bx, az-bz
  return math.sqrt(dx*dx + dz*dz)
end

local function markCircle(zone, text)
  if MARK and MARK.circle then
    pcall(function() MARK.circle(zone.name or "SM", zone.x, zone.z, zone.r, text) end)
  else
    local id = math.random(100000, 999999)
    trigger.action.markToAll(id, text, {x=zone.x,y=0,z=zone.z}, true)
  end
end

-- ---------------------------------------------------------------------------
-- Candidate areas
--   Prefers TERRAIN-provided hot zones; falls back to common editor names:
--   "CAS_*", "CAP_*", "EVENES_CAP", "BODO_CAP", etc.
-- ---------------------------------------------------------------------------
local function candidateZones(kind)
  local out = {}
  -- If TERRAIN exposes a helper, use it
  if TERRAIN and TERRAIN.fronts and TERRAIN.fronts.activeZones then
    for _,zName in ipairs(TERRAIN.fronts.activeZones(kind) or {}) do
      local z = getZone(zName); if z then out[#out+1] = z end
    end
  end
  if #out > 0 then return out end

  -- Fallback patterns
  local prefix = (kind=="INTERCEPT") and "CAP_" or (kind.."_")
  local known  = {
    "Bodo","Evenes","Andoya","Bardufoss","Kallax","Kemi Tornio","Kiruna","Vidsel","Kuusamo"
  }
  for _,base in ipairs(known) do
    local z = getZone(prefix..base)
    if z then out[#out+1] = z end
  end
  return out
end

local function pickNearestZone(kind, requesterUnitName)
  local pos = pointOfUnitName(requesterUnitName); if not pos then return nil end
  local best, bestD = nil, 1e18
  for _,z in ipairs(candidateZones(kind)) do
    local d = dist2D(pos.x, pos.z, z.x, z.z)
    if d < bestD and d <= SIDEMISSIONS.cfg.MAX_MISSION_RANGE_M then best, bestD = z, d end
  end
  return best, bestD
end

-- ---------------------------------------------------------------------------
-- Mission registry / scoring
-- ---------------------------------------------------------------------------
-- m: { id, kind, side, ownerUnit, zone, created_t, score, cap_dwell_sec, int_deadline_t, trans_watch }
SIDEMISSIONS._missions = SIDEMISSIONS._missions or {}

local function newMission(side, kind, zone, ownerUnit)
  local id = string.format("%s_%s_%06d", side, kind, math.random(999999))
  local m = { id=id, side=side, kind=kind, ownerUnit=ownerUnit, zone=zone, created_t=now(), score=0, cap_dwell_sec=0 }
  SIDEMISSIONS._missions[id] = m
  return m
end

local function expireOld()
  local ttl = (SIDEMISSIONS.cfg.AUTO_EXPIRE_MIN)*60
  for id, m in pairs(SIDEMISSIONS._missions) do
    if now() - m.created_t >= ttl then
      SIDEMISSIONS._missions[id] = nil
      say(("Mission %s expired."):format(id), 6)
    end
  end
  return now()+60
end
timer.scheduleFunction(function() return expireOld() end, {}, now()+60)

-- Credit kills inside any side-owned mission bubble (CAS/CAP)
local function onDead(e)
  if not e or e.id ~= world.event.S_EVENT_DEAD then return end

  local killer = e.initiator
  if not (killer and killer.isExist and killer.isExist and killer:isExist()) then return end

  local coal = objCoalition(killer)
  if not coal then return end
  local s = sideStr(coal)

  local tp = e.target and e.target.getPoint and e.target:getPoint()
  if not tp then return end
  for _,m in pairs(SIDEMISSIONS._missions) do
    if (m.side==s) and m.zone then
      local d = dist2D(tp.x, tp.z, m.zone.x, m.zone.z)
      if d <= (m.zone.r or SIDEMISSIONS.cfg.BUBBLE_RADIUS_M) then
        m.score = m.score + SIDEMISSIONS.cfg.SCORE_PER_KILL
        say(("Mission %s +%d score (kill in bubble)."):format(m.id, SIDEMISSIONS.cfg.SCORE_PER_KILL), 4)
        -- INT completion: any enemy air kill within window completes the mission too
        if m.kind=="INTERCEPT" and (now() <= (m.int_deadline_t or 0)) then
          say(("Mission %s INTERCEPT complete."):format(m.id), 8)
          SIDEMISSIONS._missions[m.id] = nil
        end
      end
    end
  end
end

if not SIDEMISSIONS._eh then
  SIDEMISSIONS._eh = {}
  function SIDEMISSIONS._eh:onEvent(e) onDead(e) end
  world.addEventHandler(SIDEMISSIONS._eh)
end

-- CAP dwell tracker (player must stay inside bubble for CAP_REQUIRED_SEC)
local function tickCAP()
  for _,m in pairs(SIDEMISSIONS._missions) do
    if m.kind=="CAP" and m.ownerUnit and m.zone then
      local u = Unit.getByName(m.ownerUnit)
      if u and u:isExist() then
        local p = u:getPoint()
        local d = dist2D(p.x, p.z, m.zone.x, m.zone.z)
        if d <= (m.zone.r or SIDEMISSIONS.cfg.BUBBLE_RADIUS_M) then
          m.cap_dwell_sec = (m.cap_dwell_sec or 0) + 5
          if m.cap_dwell_sec >= SIDEMISSIONS.cfg.CAP_REQUIRED_SEC then
            say(("Mission %s CAP complete: patrolled for %d min."):format(m.id, math.floor(SIDEMISSIONS.cfg.CAP_REQUIRED_SEC/60)), 8)
            SIDEMISSIONS._missions[m.id] = nil
          end
        end
      end
    end
  end
  return now()+5
end
timer.scheduleFunction(function() return tickCAP() end, {}, now()+5)

-- TRANSPORT watcher: confirm delivery by detecting resource increase at dst AF
local function tickTRANSPORT()
  for _,m in pairs(SIDEMISSIONS._missions) do
    if m.kind=="TRANSPORT" and m.trans_watch then
      local t = m.trans_watch
      if STATE and STATE.get then
        local cur = STATE.get(t.dst, t.res)
        if cur and cur >= (t.startVal + t.expectedGain) then
          say(("Mission %s TRANSPORT complete: %s increased at %s."):format(m.id, t.res, t.dst), 8)
          SIDEMISSIONS._missions[m.id] = nil
        end
      end
    end
  end
  return now()+15
end
timer.scheduleFunction(function() return tickTRANSPORT() end, {}, now()+15)

-- ---------------------------------------------------------------------------
-- Role implementations
-- ---------------------------------------------------------------------------

-- CAS: mark nearest contested area; score per ground kill inside bubble; optional friendly CAS wing
local function doCAS(requesterUnitName)
  local side = playerSide(requesterUnitName); if not side then return end
  local z, d = pickNearestZone("CAS", requesterUnitName)
  if not z then say("No CAS areas within range.", 6); return end
  local m = newMission(side, "CAS", z, requesterUnitName)
  markCircle(z, ("[%s] CAS (%.0f km)"):format(side, (d or 0)/1000))
  if AIR and TERRAIN and TERRAIN.closestOwnedAirfield then
    local af = TERRAIN.closestOwnedAirfield(side, {x=z.x, z=z.z})
    if af then pcall(function() AIR.requestWing{ side=side, role="CAS", from=af } end) end
  end
  say("CAS mission created. Destroy enemy ground inside the marked area to score.", 8)
end

-- CAP: patrol/orbit 20 min inside bubble; optional friendly CAP wing
local function doCAP(requesterUnitName)
  local side = playerSide(requesterUnitName); if not side then return end
  local z, d = pickNearestZone("CAP", requesterUnitName)
  if not z then say("No CAP areas within range.", 6); return end
  local m = newMission(side, "CAP", z, requesterUnitName)
  markCircle(z, ("[%s] CAP Patrol (%.0f km)"):format(side, (d or 0)/1000))
  if AIR and TERRAIN and TERRAIN.closestOwnedAirfield then
    local af = TERRAIN.closestOwnedAirfield(side, {x=z.x, z=z.z})
    if af then pcall(function() AIR.requestWing{ side=side, role="CAP", from=af } end) end
  end
  say(("CAP mission created. Remain inside the bubble for %d minutes."):format(math.floor(SIDEMISSIONS.cfg.CAP_REQUIRED_SEC/60)), 8)
end

-- INTERCEPT: mark nearest CAP/INTERCEPT area; give enemy-air coordinates; complete if any enemy air is killed within 20 min
local function nearestEnemyAirPos(againstSide)
  local coal = (againstSide=="RED") and coalition.side.RED or coalition.side.BLUE
  local best, bd=nil, 1e18
  for _,cat in ipairs({Group.Category.AIRPLANE, Group.Category.HELICOPTER}) do
    for _,g in ipairs(coalition.getGroups(coal, cat) or {}) do
      local u = g:getUnit(1)
      if u and u:isExist() and u:inAir() then
        local p = u:getPoint()
        local d = math.abs(p.x)+math.abs(p.z)
        if d < bd then best, bd = {x=p.x,z=p.z}, d end
      end
    end
  end
  return best
end

local function doINT(requesterUnitName)
  local side = playerSide(requesterUnitName); if not side then return end
  local enemy = (side=="BLUE") and "RED" or "BLUE"
  local z, d = pickNearestZone("INTERCEPT", requesterUnitName)
  if not z then say("No intercept areas within range.", 6); return end
  local m = newMission(side, "INTERCEPT", z, requesterUnitName)
  m.int_deadline_t = now() + 20*60
  markCircle(z, ("[%s] INTERCEPT (%.0f km) — enemy air coords sent to F10 map"):format(side, (d or 0)/1000))

  -- mark nearest known enemy aircraft/helicopter position (snapshot)
  local pos = nearestEnemyAirPos(enemy)
  if pos then
    local id = math.random(100000, 999999)
    trigger.action.markToAll(id, "Enemy AIR snapshot", {x=pos.x,y=0,z=pos.z}, true)
  end

  -- optional: spawn a small enemy strike raid inbound to give players a target
  if AIR and TERRAIN and TERRAIN.closestOwnedAirfield then
    local eAF = TERRAIN.closestOwnedAirfield(enemy, {x=z.x, z=z.z})
    if eAF then
      for i=1, SIDEMISSIONS.cfg.INTERCEPT_RAID_SIZE do
        pcall(function() AIR.requestWing{ side=enemy, role="STRIKE", from=eAF } end)
      end
    end
  end

  say("Intercept mission created. Destroy any enemy aircraft within 20 minutes.", 8)
end

-- TRANSPORT: pick neediest friendly AF near player; request logistics; complete when STATE detects gain
local function doTRANSPORT(requesterUnitName)
  local side = playerSide(requesterUnitName); if not side then return end
  if not (TRANSPORT and TERRAIN and STATE) then say("Transport system not available.", 8); return end

  local pos = pointOfUnitName(requesterUnitName); if not pos then return end
  local dst, bestD, needScore = nil, 1e18, -1
  for afName, e in pairs(TERRAIN.AIRFIELDS or {}) do
    if e.owner == ((side=="RED") and coalition.side.RED or coalition.side.BLUE) then
      local z = (e.zone and getZone(e.zone)) or getZone(afName)
      if z then
        local d = dist2D(pos.x, pos.z, z.x, z.z)
        if d <= SIDEMISSIONS.cfg.MAX_MISSION_RANGE_M and d < bestD then
          local mp, am, fu = STATE.get(afName,"manpower") or 0, STATE.get(afName,"ammo") or 0, STATE.get(afName,"fuel") or 0
          local cap = STATE.cap(afName,"manpower") or 1
          local miss = (cap-mp) + (cap-am) + (cap-fu)
          if miss > needScore then dst, bestD, needScore = afName, d, miss end
        end
      end
    end
  end
  if not dst then say("No nearby friendly base needs resupply.", 6); return end

  -- choose hub + lowest resource to target
  local mp, am, fu = STATE.get(dst,"manpower") or 0, STATE.get(dst,"ammo") or 0, STATE.get(dst,"fuel") or 0
  local res = "ammo"; if mp < am and mp < fu then res="manpower" elseif fu < am and fu < mp then res="fuel" end
  local hub = TERRAIN.closestHubFor and TERRAIN.closestHubFor(side, dst) or nil
  if not hub then say("No suitable logistics hub found.", 6); return end

  -- expected gain based on CONFIG.TRANSPORT per-mode (truck vs helo decided inside TRANSPORT)
  local truckAdd = (CONFIG and CONFIG.TRANSPORT and CONFIG.TRANSPORT.DELIVER_TRUCK) or {mp=10,ammo=20,fuel=100}
  local heloAdd  = (CONFIG and CONFIG.TRANSPORT and CONFIG.TRANSPORT.DELIVER_HELO ) or {mp=30,ammo=50,fuel=500}
  local expected = math.min(heloAdd[res] or 0, truckAdd[res] or 0)  -- at least this much
  local startVal = STATE.get(dst, res) or 0

  TRANSPORT.request{ side=side, from=hub, to=dst, res=res }
  local z = getZone(dst) or {x=0,z=0,r=SIDEMISSIONS.cfg.BUBBLE_RADIUS_M, name=dst}
  local m = newMission(side, "TRANSPORT", z, requesterUnitName)
  m.trans_watch = { dst=dst, res=res, startVal=startVal, expectedGain=expected }
  markCircle(z, ("[%s] TRANSPORT to %s (%s)").format and ("[%s] TRANSPORT to %s (%s)"):format(side,dst,res) or (side.." TRANSPORT to "..dst.." ("..res..")"))
  say(("Transport requested: %s → %s (%s). Mission will complete on delivery."):format(hub, dst, res), 8)
end

-- ---------------------------------------------------------------------------
-- F10 menu wiring (per-player)
-- ---------------------------------------------------------------------------
SIDEMISSIONS._unitMenus = SIDEMISSIONS._unitMenus or {} -- unitName -> top menu

local function bindMenusForUnit(unitName)
  if SIDEMISSIONS._unitMenus[unitName] then return end
  local u = Unit.getByName(unitName); if not (u and u:isExist() and u:getPlayerName()) then return end
  local gid = u:getGroup():getID()
  local top = missionCommands.addSubMenuForGroup(gid, "Side Missions")
  SIDEMISSIONS._unitMenus[unitName] = top
  missionCommands.addCommandForGroup(gid, "CAS (nearest area)",      top, function() doCAS(unitName) end)
  missionCommands.addCommandForGroup(gid, "CAP (20-min patrol)",      top, function() doCAP(unitName) end)
  missionCommands.addCommandForGroup(gid, "INTERCEPT (enemy air)",    top, function() doINT(unitName) end)
  missionCommands.addCommandForGroup(gid, "TRANSPORT (to needy AF)",  top, function() doTRANSPORT(unitName) end)
end

-- attach on player birth
if not SIDEMISSIONS._menuEH then
  SIDEMISSIONS._menuEH = {}
  function SIDEMISSIONS._menuEH:onEvent(e)
    if not e then return end
    if e.id == world.event.S_EVENT_BIRTH and e.initiator and e.initiator.getPlayerName and e.initiator:getPlayerName() then
      local name = e.initiator:getName()
      timer.scheduleFunction(function() bindMenusForUnit(name) return nil end, {}, now()+2)
    end
  end
  world.addEventHandler(SIDEMISSIONS._menuEH)
end

-- sweep just in case BIRTH was missed
local function sweepPlayers()
  for _,coal in ipairs({coalition.side.BLUE, coalition.side.RED}) do
    for _,cat in ipairs({Group.Category.AIRPLANE, Group.Category.HELICOPTER}) do
      for _,g in ipairs(coalition.getGroups(coal, cat) or {}) do
        local u = g:getUnit(1)
        if u and u:isExist() and u:getPlayerName() then bindMenusForUnit(u:getName()) end
      end
    end
  end
  return now()+30
end
timer.scheduleFunction(function() return sweepPlayers() end, {}, now()+5)

function SIDEMISSIONS.init()
  log("SIDEMISSIONS initialized.")
end

return SIDEMISSIONS
