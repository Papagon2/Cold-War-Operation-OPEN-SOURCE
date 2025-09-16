-- MARK.lua — economy overlays on airfields/territories
-- Reads: TERRAIN (positions/ownership), STATE (mp/ammo/fuel + caps), CONFIG.MARK
-- Public:
--   MARK.init{ interval=30 }
--   MARK.refreshNow()
--   MARK.updateAirfield(af)
--   MARK.updateAll()
--   MARK.onCapture(af)   -- optional helper; call from your capture flow

MARK = MARK or {}

-- ---------------- config view ----------------
local REFRESH_SEC     = (CONFIG and CONFIG.MARK and CONFIG.MARK.REFRESH_SEC) or 30
local SHOW_TO_ALL     = true   -- ToDo: show to all, not just owning side
local SHOW_CAPS       = true
local SHOW_INCOME     = true

-- ---------------- utils ----------------
local function getZone(name)
  if not name then return nil end
  local z = trigger.misc.getZone(name)
  if z and z.point then return { name=name, x=z.point.x, z=z.point.z, r=z.radius or 1200 } end
  return nil
end

local function fmtNum(n)
  if not n then return "0" end
  n = tonumber(n) or 0
  if n >= 1000000 then return string.format("%.1fm", n/1000000) end
  if n >= 1000    then return string.format("%.1fk", n/1000) end
  return tostring(math.floor(n + 0.5))
end

local function pct(n, d)
  n = tonumber(n) or 0; d = tonumber(d) or 0
  if d <= 0 then return "0%" end
  local p = (n/d) * 100
  return string.format("%d%%", math.floor(p + 0.5))
end

local function colorFor(side)
  if side == "BLUE" or side == coalition.side.BLUE then return {0, 0.65, 1, 1} end
  if side == "RED"  or side == coalition.side.RED  then return {1, 0.25, 0.25, 1} end
  return {0.85, 0.85, 0.85, 1}
end

local function isHub(af)
  local hubs = (CONFIG and CONFIG.STATE and CONFIG.STATE.HUBS) or {}
  if hubs[af] == true then return true end
  for i,v in ipairs(hubs) do if v == af then return true end end
  if TERRAIN and TERRAIN.AIRFIELDS and TERRAIN.AIRFIELDS[af] and (TERRAIN.AIRFIELDS[af].hub or TERRAIN.AIRFIELDS[af].isHub) then
    return true
  end
  return false
end

-- ---------------- airfield discovery ----------------
local function orderedAirfields()
  -- Prefer CONFIG.AIRFIELDS if present so labels are stable
  if CONFIG and CONFIG.AIRFIELDS then return CONFIG.AIRFIELDS end
  if TERRAIN and TERRAIN.AIRFIELDS_ORDERED then return TERRAIN.AIRFIELDS_ORDERED end
  if TERRAIN and TERRAIN.AIRFIELDS then
    local t = {}
    for af,_ in pairs(TERRAIN.AIRFIELDS) do t[#t+1] = af end
    table.sort(t); return t
  end
  if STATE and STATE.STOCK then
    local t = {}
    for af,_ in pairs(STATE.STOCK) do t[#t+1] = af end
    table.sort(t); return t
  end
  return {}
end

local function resolvePos(af)
  -- 1) TERRAIN.AIRFIELDS[af].zone (usually "Z_FRONT_*")
  if TERRAIN and TERRAIN.AIRFIELDS and TERRAIN.AIRFIELDS[af] then
    local zname = TERRAIN.AIRFIELDS[af].zone or ("Z_FRONT_"..af)
    local z = getZone(zname) or getZone(af) or getZone("AF_"..af)
    if z then return { x=z.x, y=0, z=z.z } end
  end
  -- 2) Any zone named like AF / AF_*
  local z = getZone("Z_FRONT_"..af) or getZone(af) or getZone("AF_"..af)
  if z then return { x=z.x, y=0, z=z.z } end
  -- 3) DCS airbase lookup
  if Airbase and Airbase.getByName then
    local ab = Airbase.getByName(af)
    if ab and ab.getPoint then return ab:getPoint() end
  end
  return nil
end

-- ---------------- state lookup ----------------
local function economy(af)
  local mp, ammo, fuel = 0, 0, 0
  local cap_mp, cap_ammo, cap_fuel = 0, 0, 0
  if STATE and STATE.getEconomy then
    local e = STATE.getEconomy(af)
    if e then mp, ammo, fuel = (e.manpower or 0), (e.ammo or 0), (e.fuel or 0) end
  end
  if STATE and STATE.cap then
    cap_mp   = STATE.cap(af, "mp")   or 0
    cap_ammo = STATE.cap(af, "ammo") or 0
    cap_fuel = STATE.cap(af, "fuel") or 0
  end
  local side = (STATE and STATE.getAirfieldSide and STATE.getAirfieldSide(af)) or "NEUTRAL"

  -- Income preview (per tick) from CONFIG.STATE (hubs higher)
  local inc = nil
  if CONFIG and CONFIG.STATE then
    local src = isHub(af) and CONFIG.STATE.HUB_GEN or CONFIG.STATE.BASE_GEN
    if src then inc = { mp = src.mp or 0, ammo = src.ammo or 0, fuel = src.fuel or 0 } end
  end

  return {
    side=side, mp=mp, ammo=ammo, fuel=fuel,
    cap_mp=cap_mp, cap_ammo=cap_ammo, cap_fuel=cap_fuel,
    inc=inc
  }
end

-- ---------------- drawing ----------------
MARK._ids = MARK._ids or {}   -- [af] = markId
MARK._interval = REFRESH_SEC

local function removeId(af)
  local old = MARK._ids[af]
  if old then pcall(trigger.action.removeMark, old) end
  MARK._ids[af] = nil
end

local function drawOne(af)
  local pos = resolvePos(af); if not pos then return end
  local e   = economy(af)
  local clr = colorFor(e.side)

  local hubTag = isHub(af) and " [HUB]" or ""
  local lines = {}

  -- Title
  lines[#lines+1] = string.format("%s%s  (%s)", af, hubTag, e.side)

  -- Stocks (and caps + percentage if available)
  if SHOW_CAPS and (e.cap_mp>0 or e.cap_ammo>0 or e.cap_fuel>0) then
    lines[#lines+1] = string.format("MP: %s / %s  (%s)",   fmtNum(e.mp),   fmtNum(e.cap_mp),   pct(e.mp,   e.cap_mp))
    lines[#lines+1] = string.format("AMMO: %s / %s  (%s)", fmtNum(e.ammo), fmtNum(e.cap_ammo), pct(e.ammo, e.cap_ammo))
    lines[#lines+1] = string.format("FUEL: %s / %s  (%s)", fmtNum(e.fuel), fmtNum(e.cap_fuel), pct(e.fuel, e.cap_fuel))
  else
    lines[#lines+1] = string.format("MP: %s | AMMO: %s | FUEL: %s", fmtNum(e.mp), fmtNum(e.ammo), fmtNum(e.fuel))
  end

  -- Income preview (per tick)
  if SHOW_INCOME and e.inc then
    local tick = (CONFIG and CONFIG.STATE and CONFIG.STATE.tick_sec) or 60
    lines[#lines+1] = string.format("+%d MP  +%d AMMO  +%d FUEL  (every %ss)", e.inc.mp, e.inc.ammo, e.inc.fuel, tick)
  end

  local label = table.concat(lines, "\n")

  -- assign id & draw
  removeId(af)
  local id = 700000 + math.random(1, 1000000)
  MARK._ids[af] = id

  local drawY = pos.y or land.getHeight({x=pos.x, y=pos.z})
  local p = { x=pos.x, y=drawY, z=pos.z }

  if SHOW_TO_ALL then
    trigger.action.markToAll(id, label, p, false, nil, clr)
  else
    local coal = (e.side=="BLUE" and coalition.side.BLUE) or (e.side=="RED" and coalition.side.RED) or nil
    if coal then
      trigger.action.markToCoalition(id, label, p, coal, false, nil, clr)
    else
      trigger.action.markToAll(id, label, p, false, nil, clr)
    end
  end
end

-- ---------------- public API ----------------
function MARK.clear()
  for af,_ in pairs(MARK._ids) do removeId(af) end
end

local function allAirfields()
  local list = orderedAirfields()
  -- normalize to an array of strings
  local out = {}
  for i,af in ipairs(list) do out[#out+1] = af end
  return out
end

function MARK.refreshNow()
  for _,af in ipairs(allAirfields()) do pcall(drawOne, af) end
end

function MARK.updateAirfield(af)
  if not af then return end
  removeId(af)
  pcall(drawOne, af)
end

function MARK.updateAll()
  MARK.refreshNow()
end

function MARK._loop()
  timer.scheduleFunction(function()
    MARK.refreshNow()
    return timer.getTime() + MARK._interval
  end, {}, timer.getTime() + MARK._interval)
end

function MARK.onCapture(af)
  -- helper you can call from your capture handler
  MARK.updateAirfield(af)
end

function MARK.init(opts)
  if opts and opts.interval then MARK._interval = opts.interval end
  MARK.clear()
  MARK.refreshNow()
  MARK._loop()
  if env and env.info then env.info(string.format("[MARK] Initialized; interval=%ss", MARK._interval)) end
end

pcall(function() trigger.action.outText("MARK.lua LOADED...).", 5) end)
return MARK
