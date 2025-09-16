-- ===== LOADOUT.lua (unified) =====
-- Works in two modes:
--  1) Pre-spawn templating (mutate groupData before coalition.addGroup)
--     - applyLoadoutIfAny(groupData, loadoutId)
--     - spawnAirGroup(countryId, groupData, loadoutId)
--  2) Post-spawn application (used by AIR.lua):
--     - LOADOUT.applyGroupRole(groupName, role)
--     - LOADOUT.applyByName(groupName, presetName)
--
-- Requires: PYLONS.lua loaded first (for PYLON_PRESETS; optional PYLONS.applyForGroup).
-- Honors:   CONFIG.APPLY_LOADOUTS (default true)
-- Maps:     CONFIG.AIR.LOADOUTS[role] -> preset name

LOADOUT = LOADOUT or {}

pcall(function() trigger.action.outText("[LOADOUT] LOADOUT.lua loaded ✅", 8) end)
if env and env.info then env.info("[LOADOUT] LOADOUT.lua loaded") end

if not CONFIG then CONFIG = {} end
if CONFIG.APPLY_LOADOUTS == nil then CONFIG.APPLY_LOADOUTS = true end

local function tstr(v)
  if type(v) ~= "table" then return tostring(v) end
  local ok, mist = pcall(function() return mist end)
  if ok and mist and mist.utils and mist.utils.tableShow then
    return mist.utils.tableShow(v)
  end
  local function s(tab, d)
    local pad = string.rep(" ", d)
    local bits = {}
    for k, val in pairs(tab) do
      if type(val) == "table" then
        bits[#bits+1] = string.format("%s[%s] = {\n%s\n%s}", pad, tostring(k), s(val, d+2), pad)
      else
        bits[#bits+1] = string.format("%s[%s] = %s", pad, tostring(k), tostring(val))
      end
    end
    return table.concat(bits, "\n")
  end
  return "{\n"..s(v,2).."\n}"
end

local function log(msg) if env and env.info then env.info("[LOADOUT] "..msg) end end
local function warn(msg)
  if env and env.warning then env.warning("[LOADOUT] "..msg) end
  if env and env.info then env.info("[LOADOUT][WARN] "..msg) end
end

-- ---------- validation ----------
local function isValidPylon(p, stationKey)
  return type(p)=="table" and type(p.CLSID)=="string"
     and (type(p.num)=="number" or type(stationKey)=="number")
end

local function isValidPayload(pl)
  if type(pl)~="table" or type(pl.pylons)~="table" then return false end
  for idx, p in pairs(pl.pylons) do if not isValidPylon(p, idx) then return false end end
  return true
end

-- ---------- build payload (pre-spawn) ----------
local function buildPayloadFor(typeName, loadoutId)
  if not CONFIG.APPLY_LOADOUTS then return nil,"disabled" end
  if not PYLON_PRESETS then return nil,"nopresets" end
  if not typeName then return nil,"notype" end

  local byType = PYLON_PRESETS[typeName]
  if not byType then return nil,"type-missing" end
  local preset = byType[loadoutId]
  if not preset then return nil,"preset-missing" end

  local payload = {
    fuel  = preset.fuel or nil,
    flare = preset.flare or 0,
    chaff = preset.chaff or 0,
    gun   = preset.gun   or 100,
    pylons = {}
  }
  local used = {}
  for k,v in pairs(preset.pylons or {}) do
    local station = tonumber(v.num) or (type(k)=="number" and k or nil)
    local clsid   = v.CLSID
    if station and clsid then
      if used[station] then
        warn(("Duplicate station %s on %s/%s; keeping first, drop %s")
          :format(station, typeName, tostring(loadoutId), clsid))
      else
        payload.pylons[station] = { CLSID = clsid, num = station }
        used[station] = true
      end
    else
      warn(("Bad pylon entry on %s/%s: k=%s data=%s")
        :format(typeName, tostring(loadoutId), tostring(k), tstr(v)))
    end
  end

  if not isValidPayload(payload) then
    return nil,"invalid"
  end
  return payload
end

-- ---------- apply to template unit ----------
local function applyToTemplateUnit(unit, loadoutId)
  local payload, err = buildPayloadFor(unit.type, loadoutId)
  if not payload then
    if err ~= "disabled" and err ~= "nopresets" and err ~= "preset-missing" then
      warn("Template payload build failed: "..tostring(err))
    end
    return false
  end
  unit.payload = payload
  return true
end

-- ========== PUBLIC (pre-spawn) ==========
function applyLoadoutIfAny(groupData, loadoutId)
  if type(groupData) ~= "table" or type(groupData.units) ~= "table" then
    warn("applyLoadoutIfAny got invalid groupData"); return groupData
  end
  if not loadoutId or not CONFIG.APPLY_LOADOUTS then return groupData end

  local applied, tried = 0, 0
  for _,u in ipairs(groupData.units) do
    if not (u.skill=="Client" or u.skill=="Player") then
      tried = tried + 1
      if applyToTemplateUnit(u, loadoutId) then applied = applied + 1 end
    end
  end
  log(string.format("applyLoadoutIfAny('%s'): tried=%d, applied=%d", tostring(loadoutId), tried, applied))
  return groupData
end

function spawnAirGroup(countryId, groupData, loadoutId)
  if type(groupData) ~= "table" then warn("spawnAirGroup invalid groupData"); return nil end
  groupData.category = groupData.category or Group.Category.AIRPLANE
  if loadoutId then applyLoadoutIfAny(groupData, loadoutId) end
  local ok, res = pcall(function() return coalition.addGroup(countryId, groupData.category, groupData) end)
  if not ok or not res then
    warn("coalition.addGroup failed: "..tostring(res)); warn("group dump:\n"..tstr(groupData)); return nil
  end
  log("Group spawned: "..(groupData.name or "<noname>"))
  return res
end

-- ========== PUBLIC (post-spawn; used by AIR.lua) ==========
-- These APIs let us spawn first (AIR.lua) and then apply pylons safely if PYLONS provides a runtime applier.

-- Apply using a mission “role” → preset mapping from CONFIG.AIR.LOADOUTS
function LOADOUT.applyGroupRole(groupName, role)
  if not CONFIG.APPLY_LOADOUTS then return false end
  local map = (CONFIG and CONFIG.AIR and CONFIG.AIR.LOADOUTS) or {}
  local preset = map and map[role]
  if not preset then
    log("applyGroupRole: no preset mapped for role "..tostring(role).." (ok)"); return false
  end
  return LOADOUT.applyByName(groupName, preset)
end

-- Apply by a concrete preset name (expects PYLON_PRESETS[type][preset])
function LOADOUT.applyByName(groupName, presetName)
  if not CONFIG.APPLY_LOADOUTS then return false end
  local g = Group.getByName(groupName)
  if not g or not g:isExist() then warn("applyByName: group not found "..tostring(groupName)); return false end

  -- If PYLONS exposes a live applier, use it (best effort & mission-safe).
  if PYLONS and PYLONS.applyForGroup then
    local ok, err = pcall(function() return PYLONS.applyForGroup(groupName, presetName) end)
    if ok then
      log(("Applied preset '%s' to group %s via PYLONS.applyForGroup"):format(presetName, groupName))
      return true
    else
      warn("PYLONS.applyForGroup failed: "..tostring(err))
      return false
    end
  end

  -- Fallback: no live applier available -> we can’t mutate payloads post-spawn.
  warn("No runtime pylon applier available (PYLONS.applyForGroup missing). Leaving default payloads.")
  return false
end

-- Convenience used by AIR.lua’s helper (optional; idempotent)
function LOADOUT.applyGroupName(groupName, loadoutId)  -- alias
  return LOADOUT.applyByName(groupName, loadoutId)
end

pcall(function() trigger.action.outText("LOADOUT.lua ready (pre/post spawn).", 5) end)
return LOADOUT
-- ===== end LOADOUT.lua =====
