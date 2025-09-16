-- TERRAIN.lua — Airfield registry, ownership, fronts & helpers
-- Meets ToDo: collect ownership and tell relevant modules who owns what;
-- expose active front pairs/zones for GROUND/AIR/SIDEMISSIONS/MARK.

TERRAIN = TERRAIN or {}

local function now() return timer.getTime() end
local function say(t, d) trigger.action.outText("[TERRAIN] "..tostring(t), d or 5) end
local function info(t) if env and env.info then env.info("[TERRAIN] "..tostring(t)) end end

---------------------------------------------------------------------
-- Small helpers
---------------------------------------------------------------------
local function getZone(name)
  if not name then return nil end
  local z = trigger.misc.getZone(name)
  if z and z.point then return { name=name, x=z.point.x, y=0, z=z.point.z, r=z.radius or 1200 } end
  return nil
end

local function dist2(a,b) local dx=a.x-b.x; local dz=a.z-b.z; return math.sqrt(dx*dx+dz*dz) end
local function toSideStr(side) return (side == coalition.side.RED) and "RED" or (side == coalition.side.BLUE) and "BLUE" or "NEUTRAL" end

---------------------------------------------------------------------
-- Airfield registry (initial ownership + neighbors + hub flags)
-- Hubs per ToDo: Bodo, Kallax, Kemi Tornio, Severomorsk-1, Severomorsk-3, Poduzhemye
---------------------------------------------------------------------
TERRAIN.AIRFIELDS = {
  -- BLUE start
  ["Bodo"]                           = { zone="Z_FRONT_Bodo",                   owner=coalition.side.BLUE, neighbors={"Evenes","Kiruna","Jokkmokk","Vidsel"},                        isHub=true },
  ["Kallax"]                         = { zone="Z_FRONT_Kallax",                 owner=coalition.side.BLUE, neighbors={"Kemi Tornio","Vidsel"},                                        isHub=true },
  ["Kemi Tornio"]                    = { zone="Z_FRONT_Kemi Tornio",            owner=coalition.side.BLUE, neighbors={"Hosio","Kallax","Rovaniemi"},                                 isHub=true },

  -- RED start (all others)
  ["Evenes"]                         = { zone="Z_FRONT_Evenes",                 owner=coalition.side.RED,  neighbors={"Bodo","Bardufoss","Andoya","Kiruna"} },
  ["Andoya"]                         = { zone="Z_FRONT_Andoya",                 owner=coalition.side.RED,  neighbors={"Evenes","Bardufoss","Alta"} },
  ["Kiruna"]                         = { zone="Z_FRONT_Kiruna",                 owner=coalition.side.RED,  neighbors={"Bodo","Evenes","Bardufoss","Jokkmokk","Enontekio","Kittila","Vuojarvi"} },
  ["Vidsel"]                         = { zone="Z_FRONT_Vidsel",                 owner=coalition.side.RED,  neighbors={"Bodo","Jokkmokk","Kallax"} },
  ["Kuusamo"]                        = { zone="Z_FRONT_Kuusamo",                owner=coalition.side.RED,  neighbors={"Kalevala","Hosio","Rovaniemi"} },
  ["Poduzhemye"]                     = { zone="Z_FRONT_Poduzhemye",             owner=coalition.side.RED,  neighbors={"Kalevala","Alakurtti","Afrikanda"},                           isHub=true },
  ["Afrikanda"]                      = { zone="Z_FRONT_Afrikanda",              owner=coalition.side.RED,  neighbors={"Poduzhemye","Alakurtti","Monchegorsk","Sodankyla"} },
  ["Olenya"]                         = { zone="Z_FRONT_Olenya",                 owner=coalition.side.RED,  neighbors={"Murmansk International","Severomorsk-3","Monchegorsk"} },
  ["Severomorsk-1"]                  = { zone="Z_FRONT_Severomorsk-1",          owner=coalition.side.RED,  neighbors={"Murmansk International","Severomorsk-3","Kilpyavr","Luostari Pechenga"}, isHub=true },
  ["Severomorsk-3"]                  = { zone="Z_FRONT_Severomorsk-3",          owner=coalition.side.RED,  neighbors={"Severomorsk-1","Murmansk International","Olenya"},            isHub=true },
  ["Murmansk International"]         = { zone="Z_FRONT_Murmansk International", owner=coalition.side.RED,  neighbors={"Olenya","Severomorsk-3","Severomorsk-1","Kilpyavr","Koshka Yavr","Ivalo"} },
  ["Kilpyavr"]                       = { zone="Z_FRONT_Kilpyavr",               owner=coalition.side.RED,  neighbors={"Luostari Pechenga","Koshka Yavr","Murmansk International","Severomorsk-1"} },
  ["Koshka Yavr"]                    = { zone="Z_FRONT_Koshka Yavr",            owner=coalition.side.RED,  neighbors={"Kilpyavr","Luostari Pechenga","Murmansk International","Ivalo"} },
  ["Ivalo"]                          = { zone="Z_FRONT_Ivalo",                  owner=coalition.side.RED,  neighbors={"Koshka Yavr","Murmansk International","Kirkenes","Kittila","Enontekio"} },
  ["Kittila"]                        = { zone="Z_FRONT_Kittila",                owner=coalition.side.RED,  neighbors={"Enontekio","Ivalo","Sodankyla","Kiruna"} },
  ["Alta"]                           = { zone="Z_FRONT_Alta",                   owner=coalition.side.RED,  neighbors={"Andoya","Bardufoss","Banak","Enontekio"} },
  ["Banak"]                          = { zone="Z_FRONT_Banak",                  owner=coalition.side.RED,  neighbors={"Alta","Enontekio","Ivalo","Kirkenes"} },
  ["Vuojarvi"]                       = { zone="Z_FRONT_Vuojarvi",               owner=coalition.side.RED,  neighbors={"Alakurtti","Sodankyla","Rovaniemi","Kiruna"} },
  ["Bardufoss"]                      = { zone="Z_FRONT_Bardufoss",              owner=coalition.side.RED,  neighbors={"Andoya","Evenes","Kiruna","Enontekio","Alta"} },
  ["Jokkmokk"]                       = { zone="Z_FRONT_Jokkmokk",               owner=coalition.side.RED,  neighbors={"Rovaniemi","Vidsel","Kiruna","Bodo"} },
  ["Rovaniemi"]                      = { zone="Z_FRONT_Rovaniemi",              owner=coalition.side.RED,  neighbors={"Jokkmokk","Kemi Tornio","Hosio","Vuojarvi","Kuusamo","Alakurtti"} },
  ["Alakurtti"]                      = { zone="Z_FRONT_Alakurtti",              owner=coalition.side.RED,  neighbors={"Rovaniemi","Vuojarvi","Sodankyla","Afrikanda","Kalevala","Poduzhemye"} },
  ["Monchegorsk"]                    = { zone="Z_FRONT_Monchegorsk",            owner=coalition.side.RED,  neighbors={"Olenya","Afrikanda"} },
  ["Luostari Pechenga"]              = { zone="Z_FRONT_Luostari Pechenga",      owner=coalition.side.RED,  neighbors={"Kirkenes","Ivalo","Kilpyavr","Koshka Yavr","Severomorsk-1"} },
  ["Kirkenes"]                       = { zone="Z_FRONT_Kirkenes",               owner=coalition.side.RED,  neighbors={"Luostari Pechenga","Ivalo","Banak"} },
  ["Sodankyla"]                      = { zone="Z_FRONT_Sodankyla",              owner=coalition.side.RED,  neighbors={"Vuojarvi","Kittila","Alakurtti"} },
  ["Enontekio"]                      = { zone="Z_FRONT_Enontekio",              owner=coalition.side.RED,  neighbors={"Kittila","Ivalo","Kiruna","Bardufoss","Alta"} },
  ["Kalevala"]                       = { zone="Z_FRONT_Kalevala",               owner=coalition.side.RED,  neighbors={"Poduzhemye","Kuusamo","Alakurtti"} },
  ["Hosio"]                          = { zone="Z_FRONT_Hosio",                  owner=coalition.side.RED,  neighbors={"Kuusamo","Rovaniemi","Kemi Tornio"} },
}

-- Provide a stable order for UIs/markers
TERRAIN.AIRFIELDS_ORDERED = (CONFIG and CONFIG.AIRFIELDS) or (function()
  local t = {}
  for k,_ in pairs(TERRAIN.AIRFIELDS) do t[#t+1] = k end
  table.sort(t); return t
end)()

---------------------------------------------------------------------
-- Ownership helpers
---------------------------------------------------------------------
function TERRAIN.getOwner(af)
  local e = TERRAIN.AIRFIELDS[af]; return e and e.owner or nil
end

function TERRAIN.setOwner(af, newOwner)
  local e = TERRAIN.AIRFIELDS[af]; if not e then return end
  local oldOwner = e.owner
  if oldOwner == newOwner then return end
  e.owner = newOwner

  -- Notify other systems (redundant with OPERATIONINIT event hook but safe if setOwner is called directly)
  if STATE and STATE.onCapture then STATE.onCapture(af, toSideStr(newOwner), toSideStr(oldOwner)) end
  if MARK and (MARK.onCapture or MARK.updateAirfield) then
    if MARK.onCapture then MARK.onCapture(af) else MARK.updateAirfield(af) end
  end
  if AIR and AIR.support and AIR.support.onCapture then AIR.support.onCapture(af, toSideStr(newOwner), toSideStr(oldOwner)) end

  say(string.format("%s captured by %s!", af, toSideStr(newOwner)), 8)
end

function TERRAIN.isAirfieldActive(af)
  return TERRAIN.AIRFIELDS[af] ~= nil
end

function TERRAIN.isFrontActive(fromAF, toAF)
  local a, b = TERRAIN.AIRFIELDS[fromAF], TERRAIN.AIRFIELDS[toAF]
  if not (a and b) then return false end
  return a.owner ~= b.owner
end

---------------------------------------------------------------------
-- Front graph (unique undirected edges from neighbor lists)
---------------------------------------------------------------------
TERRAIN.FRONT_PAIRS = {}
do
  local seen = {}
  for af,e in pairs(TERRAIN.AIRFIELDS) do
    for _,nbr in ipairs(e.neighbors or {}) do
      if TERRAIN.AIRFIELDS[nbr] then
        local a,b = af, nbr; if a > b then a,b = b,a end
        local key = a.."|"..b
        if not seen[key] then
          seen[key] = true
          table.insert(TERRAIN.FRONT_PAIRS, { from=a, to=b })
        end
      end
    end
  end
end

function TERRAIN.getActiveFrontPairs()
  local out = {}
  for _,p in ipairs(TERRAIN.FRONT_PAIRS) do
    if TERRAIN.isFrontActive(p.from, p.to) then out[#out+1] = { from=p.from, to=p.to } end
  end
  return out
end

---------------------------------------------------------------------
-- Convenience lookups (used by AIR, TRANSPORT, etc.)
---------------------------------------------------------------------
function TERRAIN.closestOwnedAirfield(sideStrIn, point)
  local side = (sideStrIn=="RED") and coalition.side.RED or coalition.side.BLUE
  local best, bd = nil, 1e18
  for af, e in pairs(TERRAIN.AIRFIELDS) do
    if e.owner == side then
      local z = getZone(e.zone) or getZone(af)
      if z and point then
        local d = dist2({x=z.x, z=z.z}, {x=point.x, z=point.z})
        if d < bd then best, bd = af, d end
      elseif z and not point then
        return af
      end
    end
  end
  return best
end

-- If no hubs are flagged (or you want to force hubs from CONFIG), we sync in init().
function TERRAIN.closestHubFor(sideStrIn, toAF)
  local side = (sideStrIn=="RED") and coalition.side.RED or coalition.side.BLUE
  local dest = TERRAIN.AIRFIELDS[toAF]; if not dest then return nil end
  local zt = getZone(dest.zone) or getZone(toAF); if not zt then return nil end

  local best, bd = nil, 1e18
  local anyHub = false
  for _,e in pairs(TERRAIN.AIRFIELDS) do if e.isHub then anyHub = true; break end end

  for af,e in pairs(TERRAIN.AIRFIELDS) do
    if e.owner==side and ((anyHub and e.isHub) or (not anyHub)) then
      local z = getZone(e.zone) or getZone(af)
      if z then
        local d = dist2({x=z.x, z=z.z}, {x=zt.x, z=zt.z})
        if d < bd then best, bd = af, d end
      end
    end
  end
  return best
end

function TERRAIN.getActiveHomeFor(sideStrIn)
  local side = (sideStrIn=="RED") and coalition.side.RED or coalition.side.BLUE
  for af,e in pairs(TERRAIN.AIRFIELDS) do if e.owner==side and e.isHub then return af end end
  for af,e in pairs(TERRAIN.AIRFIELDS) do if e.owner==side then return af end end
  return nil
end

---------------------------------------------------------------------
-- Fronts API for SIDEMISSIONS and others
---------------------------------------------------------------------
TERRAIN.fronts = TERRAIN.fronts or {}

function TERRAIN.fronts.activePairs()
  return TERRAIN.getActiveFrontPairs()
end

function TERRAIN.fronts.activeZones(kind)
  local zones, added = {}, {}
  for _,p in ipairs(TERRAIN.getActiveFrontPairs()) do
    for _,af in ipairs({p.from, p.to}) do
      local e = TERRAIN.AIRFIELDS[af]
      if e and not added[af] then
        zones[#zones+1] = e.zone or ("Z_FRONT_"..af)
        added[af] = true
      end
    end
  end
  return zones
end

---------------------------------------------------------------------
-- Init: sync hubs from CONFIG (optional) & validate zones
---------------------------------------------------------------------
function TERRAIN.init()
  -- Sync hub flags from CONFIG.STATE.HUBS so CONFIG remains the single source of truth
  local hubs = (CONFIG and CONFIG.STATE and CONFIG.STATE.HUBS) or {}
  if type(hubs)=="table" then
    local set = {}
    for k,v in pairs(hubs) do
      if type(k)=="number" then set[v]=true else if v==true then set[k]=true end end
    end
    for af,e in pairs(TERRAIN.AIRFIELDS) do e.isHub = set[af] or e.isHub end
  end

  -- Optional: warn for missing Z_FRONT_* zones
  local missing = {}
  for af,e in pairs(TERRAIN.AIRFIELDS) do
    if not (getZone(e.zone) or getZone(af) or Airbase.getByName(af)) then
      missing[#missing+1] = string.format("%s (expects zone '%s')", af, e.zone)
    end
  end
  if #missing > 0 then
    env.info("[TERRAIN] Warning: missing zones/airbases for:\n - "..table.concat(missing, "\n - "))
  end

  info("TERRAIN initialized.")
end

info("TERRAIN.lua loaded.")
return TERRAIN
