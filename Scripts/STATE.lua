-- STATE.lua — Economy & shared runtime state for Operation Cold-War Breach
-- Single source of truth for resources + helper cost functions used by all modules.

STATE = STATE or {}

---------------------------------------------------------------------
-- Small utils
---------------------------------------------------------------------
local function now() return timer.getTime() end
local function info(t) if env and env.info then env.info("[STATE] "..tostring(t)) end end
local function say (t,d) trigger.action.outText("[STATE] "..tostring(t), d or 5) end
local function clamp(v,lo,hi) if v<lo then return lo elseif v>hi then return v end return hi end

---------------------------------------------------------------------
-- Config view (populated from CONFIG.STATE, with safe defaults)
---------------------------------------------------------------------
STATE.cfg = {
  tick_sec    = (CONFIG and CONFIG.STATE and CONFIG.STATE.tick_sec) or 60,
  HUB_GEN     = (CONFIG and CONFIG.STATE and CONFIG.STATE.HUB_GEN) or { mp=9,  ammo=45, fuel=60 },
  BASE_GEN    = (CONFIG and CONFIG.STATE and CONFIG.STATE.BASE_GEN) or { mp=3, ammo=15, fuel=20 },
  DEFAULT_CAP = (CONFIG and CONFIG.STATE and CONFIG.STATE.DEFAULT_CAP) or { mp=5000, ammo=8000, fuel=12000 },
  HUBS        = (CONFIG and CONFIG.STATE and CONFIG.STATE.HUBS) or {},
  SEED_DEFAULT= (CONFIG and CONFIG.STATE and CONFIG.STATE.SEED_DEFAULT) or { mp=800, ammo=1500, fuel=2500 },
  SEED        = (CONFIG and CONFIG.STATE and CONFIG.STATE.SEED) or {},
  DEBUG       = (CONFIG and CONFIG.STATE and CONFIG.STATE.debug) or false,
}

local function dbg(t)
  if STATE.cfg.DEBUG then trigger.action.outText("[STATE:DBG] "..tostring(t), 5) end
end

---------------------------------------------------------------------
-- Data stores
---------------------------------------------------------------------
-- Per-airfield stock & caps
STATE.STOCK = STATE.STOCK or {}   -- [af] = { mp=, ammo=, fuel= }
STATE.CAP   = STATE.CAP   or {}   -- [af] = { mp=, ammo=, fuel= }

-- Optional: shared route memory (used by GROUND/FERRY etc.)
STATE.ROUTES       = STATE.ROUTES       or {}   -- [groupName] = { points = {...} }
STATE.FERRY_CHAINS = STATE.FERRY_CHAINS or {}   -- [groupName] = chain

---------------------------------------------------------------------
-- Ownership helpers
---------------------------------------------------------------------
local function ownedSideStr(af)
  if TERRAIN and TERRAIN.getOwner then
    local o = TERRAIN.getOwner(af)
    if o=="BLUE" or o==coalition.side.BLUE or o==2 then return "BLUE" end
    if o=="RED"  or o==coalition.side.RED  or o==1 then return "RED"  end
  end
  return nil -- unknown/neutral
end

local function isHub(af)
  -- Accept list or set in CONFIG.STATE.HUBS
  local hs = STATE.cfg.HUBS
  if type(hs)=="table" then
    if hs[af]==true then return true end
    for i,v in ipairs(hs) do if v==af then return true end end
  end
  -- Also allow a TERRAIN metadata flag if present
  if TERRAIN and TERRAIN.AIRFIELDS and TERRAIN.AIRFIELDS[af] then
    local e = TERRAIN.AIRFIELDS[af]
    if e.isHub or e.hub then return true end
  end
  return false
end

---------------------------------------------------------------------
-- Ensure AF record exists
---------------------------------------------------------------------
local function ensureAf(af)
  if not af then return end
  if not STATE.STOCK[af] then STATE.STOCK[af] = { mp=0, ammo=0, fuel=0 } end
  if not STATE.CAP[af]   then
    STATE.CAP[af] = {
      mp   = STATE.cfg.DEFAULT_CAP.mp,
      ammo = STATE.cfg.DEFAULT_CAP.ammo,
      fuel = STATE.cfg.DEFAULT_CAP.fuel
    }
  end
end

---------------------------------------------------------------------
-- MARK bridgers (public)
---------------------------------------------------------------------
function STATE.getEconomy(af)
  ensureAf(af)
  return {
    manpower = STATE.STOCK[af].mp,
    ammo     = STATE.STOCK[af].ammo,
    fuel     = STATE.STOCK[af].fuel,
  }
end

function STATE.getAirfieldSide(af)
  return ownedSideStr(af) or "NEUTRAL"
end

---------------------------------------------------------------------
-- Public economy API
---------------------------------------------------------------------
function STATE.get(af, key) ensureAf(af); return STATE.STOCK[af][key] end
function STATE.cap(af, key) ensureAf(af); return STATE.CAP[af][key]   end

local function _add(af, key, amt)
  ensureAf(af)
  local cap = STATE.CAP[af][key] or 0
  STATE.STOCK[af][key] = math.max(0, math.min((STATE.STOCK[af][key] or 0) + (tonumber(amt) or 0), cap))
end

local function _sub(af, key, amt)
  ensureAf(af)
  local have = STATE.STOCK[af][key] or 0
  amt = math.max(0, tonumber(amt) or 0)
  if have < amt then return false end
  STATE.STOCK[af][key] = have - amt
  return true
end

local function _markUpdate(af)
  if MARK and MARK.updateAirfield then MARK.updateAirfield(af) end
end

-- Basic resource helpers (with MARK updates)
function STATE.add(af, key, amt) _add(af, key, amt); _markUpdate(af); return true end
function STATE.take(af, key, amt) local ok=_sub(af, key, amt); if ok then _markUpdate(af) end; return ok end
function STATE.give(af, key, amt) return STATE.add(af, key, amt) end
function STATE.consume(af,key,amt) return STATE.take(af, key, amt) end

-- Convenience: composite checks and debits
function STATE.hasResources(af, side, cost)
  ensureAf(af); if not cost then return true end
  local s = STATE.STOCK[af]
  return (s.mp   >= (cost.mp   or 0)) and
         (s.ammo >= (cost.ammo or 0)) and
         (s.fuel >= (cost.fuel or 0))
end
function STATE.canAfford(af, side, cost) return STATE.hasResources(af, side, cost) end

function STATE.debit(af, side, cost)
  if not cost then return true end
  if not STATE.hasResources(af, side, cost) then return false end
  STATE.STOCK[af].mp   = STATE.STOCK[af].mp   - (cost.mp   or 0)
  STATE.STOCK[af].ammo = STATE.STOCK[af].ammo - (cost.ammo or 0)
  STATE.STOCK[af].fuel = STATE.STOCK[af].fuel - (cost.fuel or 0)
  _markUpdate(af)
  return true
end

function STATE.affordAndDebit(af, side, cost)
  if STATE.debit(af, side, cost) then return true end
  return false
end

-- Adjust per-AF caps (e.g., FOB upgrades)
function STATE.setCap(af, capTbl)
  ensureAf(af)
  for k,v in pairs(capTbl or {}) do
    local nv = math.max(0, tonumber(v) or STATE.CAP[af][k])
    STATE.CAP[af][k] = nv
    -- clamp existing stock to new cap
    STATE.STOCK[af][k] = math.max(0, math.min(STATE.STOCK[af][k], nv))
  end
  _markUpdate(af)
end

-- Register/seed a new AF
function STATE.registerAirfield(af, opts)
  ensureAf(af)
  if opts and opts.cap  then STATE.setCap(af, opts.cap) end
  if opts and opts.init then
    for k,v in pairs(opts.init) do _add(af, k, v) end
    _markUpdate(af)
  end
end

---------------------------------------------------------------------
-- Cost calculators (for spawners to build {mp,ammo,fuel})
-- ToDo rules:
--  Manpower: 1 crew=10, 2 crew=15, >=3 crew=20
--  Ammo: each missile=1; rocket-pod counts HALF total rockets; ground unit rounds cost HALF; arty shells HALF
--  Fuel: aircraft fuel gallons = fuel; ground vehicle with engine = 100; infantry = 0
---------------------------------------------------------------------
function STATE.calcManpower(crewCount)
  local c = tonumber(crewCount or 1) or 1
  if c <= 1 then return 10
  elseif c == 2 then return 15
  else return 20 end
end

-- stats = {
--   missiles = n,
--   rockets  = n,   -- total rockets carried (across pods)
--   ground_rounds = n, -- MG/MBT general ammo (non-arty)
--   arty_shells   = n,
-- }
function STATE.calcAmmoCost(stats)
  stats = stats or {}
  local missiles = tonumber(stats.missiles or 0) or 0
  local rockets  = tonumber(stats.rockets  or 0) or 0
  local ground   = tonumber(stats.ground_rounds or 0) or 0
  local arty     = tonumber(stats.arty_shells   or 0) or 0
  local cost = 0
  cost = cost + missiles                      -- missile: 1 each
  cost = cost + math.floor(rockets * 0.5)     -- pod: half the rockets
  cost = cost + math.floor(ground  * 0.5)     -- ground unit: half rounds
  cost = cost + math.floor(arty    * 0.5)     -- artillery shells: half
  if cost < 0 then cost = 0 end
  return cost
end

-- fuel = {
--   isAircraft = bool,
--   fuelGallons = n,   -- only used if isAircraft
--   isGroundVehicle = bool,
--   isInfantry = bool
-- }
function STATE.calcFuelCost(fuel)
  fuel = fuel or {}
  if fuel.isInfantry then return 0 end
  if fuel.isAircraft then
    local g = tonumber(fuel.fuelGallons or 0) or 0
    return math.max(0, math.floor(g)) -- 1 gallon = 1 fuel
  end
  if fuel.isGroundVehicle then
    return 100
  end
  return 0
end

-- Convenience to build a composite cost if a module can provide counts.
-- Pass any subset of these; missing fields simply contribute 0.
-- spec = {
--   crew = n,
--   missiles = n, rockets = n, ground_rounds = n, arty_shells = n,
--   isAircraft = bool, fuelGallons = n, isGroundVehicle = bool, isInfantry = bool
-- }
function STATE.buildCost(spec)
  spec = spec or {}
  local mp   = STATE.calcManpower(spec.crew or 1)
  local ammo = STATE.calcAmmoCost{
    missiles      = spec.missiles,
    rockets       = spec.rockets,
    ground_rounds = spec.ground_rounds,
    arty_shells   = spec.arty_shells,
  }
  local fuel = STATE.calcFuelCost{
    isAircraft      = spec.isAircraft,
    fuelGallons     = spec.fuelGallons,
    isGroundVehicle = spec.isGroundVehicle,
    isInfantry      = spec.isInfantry,
  }
  return { mp=mp, ammo=ammo, fuel=fuel }
end

---------------------------------------------------------------------
-- Income tick (hub vs base) – only for owned AFs
---------------------------------------------------------------------
local function _incomeTick()
  -- Source list: TERRAIN if present, else anything we’ve seen
  local list = {}
  if TERRAIN and TERRAIN.AIRFIELDS then
    for afName,_ in pairs(TERRAIN.AIRFIELDS) do list[#list+1] = afName end
  else
    for afName,_ in pairs(STATE.STOCK) do list[#list+1] = afName end
  end

  for _,af in ipairs(list) do
    ensureAf(af)
    local side = ownedSideStr(af)
    if side then
      local gen = isHub(af) and STATE.cfg.HUB_GEN or STATE.cfg.BASE_GEN
      if gen then
        _add(af, "mp",   gen.mp   or 0)
        _add(af, "ammo", gen.ammo or 0)
        _add(af, "fuel", gen.fuel or 0)
        _markUpdate(af)
      end
    end
  end
  return now() + (STATE.cfg.tick_sec or 60)
end

---------------------------------------------------------------------
-- Capture hook (call from TERRAIN/AIR when AF changes owner)
---------------------------------------------------------------------
function STATE.onCapture(af, newSide, oldSide)
  ensureAf(af)
  dbg(string.format("Capture: %s  %s -> %s", tostring(af), tostring(oldSide), tostring(newSide)))
  -- Example penalty (disabled by default):
  -- STATE.STOCK[af].mp   = math.floor(STATE.STOCK[af].mp   * 0.50)
  -- STATE.STOCK[af].ammo = math.floor(STATE.STOCK[af].ammo * 0.50)
  -- STATE.STOCK[af].fuel = math.floor(STATE.STOCK[af].fuel * 0.75)
  _markUpdate(af)
end

---------------------------------------------------------------------
-- Init (seed caps & stocks, start income loop)
---------------------------------------------------------------------
function STATE.init()
  if STATE._armed then return end
  STATE._armed = true

  -- Seed explicit entries from CONFIG
  for af,rec in pairs(STATE.cfg.SEED) do
    STATE.registerAirfield(af, rec)
  end

  -- Apply SEED_DEFAULT to all known AFs with zeroed stock
  local list = {}
  if TERRAIN and TERRAIN.AIRFIELDS then
    for af,_ in pairs(TERRAIN.AIRFIELDS) do list[#list+1] = af end
  else
    for af,_ in pairs(STATE.STOCK) do list[#list+1] = af end
  end
  for _,af in ipairs(list) do
    ensureAf(af)
    local s = STATE.STOCK[af]
    if (s.mp==0) and (s.ammo==0) and (s.fuel==0) then
      STATE.registerAirfield(af, { init = STATE.cfg.SEED_DEFAULT })
    end
  end

  -- Kick off income tick
  timer.scheduleFunction(function() return _incomeTick() end, {}, now() + (STATE.cfg.tick_sec or 60))

  info("STATE initialized.")
  -- Optional: let MARK draw initial values immediately
  if MARK and MARK.updateAll then MARK.updateAll() end
end

info("STATE.lua loaded.")
return STATE
