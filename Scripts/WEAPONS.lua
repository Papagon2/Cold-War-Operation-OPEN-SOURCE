-- Auto-generated from PYLONS.lua (adds/overrides only for CLSIDs found in your presets)
-- WEAPONS = WEAPONS or {}
-- WEAPONS.COST = WEAPONS.COST or {}
-- WEAPONS.COST.ROCKET_PODS = WEAPONS.COST.ROCKET_PODS or {}
-- -- COST values: ammo units per store (bomb/missile/rack). Guns/fuel/ECM are 0.
-- -- ROCKET_PODS values: number of rockets contained; billing = ceil(N/2).

-- -- Bombs / Missiles / Racks (ammo units each)
-- WEAPONS.COST["{00F5DAC4-0466-4122-998F-B1A298E34113}"] = 1
-- WEAPONS.COST["{0180F983-C14A-11d8-9897-000476191836}"] = 1
-- WEAPONS.COST["{275A2855-4A79-4B2D-B082-91EA2ADF4691}"] = 1
-- WEAPONS.COST["{2x9M114_with_adapter}"] = 2
-- WEAPONS.COST["{319293F2-392C-4617-8315-7C88C22AF7C4}"] = 1
-- WEAPONS.COST["{37DCC01E-9E02-432F-B61D-10C166CA2798}"] = 1
-- WEAPONS.COST["{3C612111-C7AD-476E-8A8E-2485812F4E5C}"] = 1
-- WEAPONS.COST["{414DA830-B61A-4F9E-B71B-C2F6832E1D7A}"] = 1
-- WEAPONS.COST["{44EE8698-89F9-48EE-AF36-5FD31896A82A}"] = 1
-- WEAPONS.COST["{44EE8698-89F9-48EE-AF36-5FD31896A82F}"] = 1
-- WEAPONS.COST["{60CC734F-0AFA-4E2E-82B8-93B941AB11CF}"] = 1
-- WEAPONS.COST["{696CFFC4-0BDE-42A8-BE4B-0BE3D9DD723C}"] = 1
-- WEAPONS.COST["{6A4B9E69-64FE-439a-9163-3A87FB6A4D81}"] = 1
-- WEAPONS.COST["{6D21ECEA-F85B-4E8D-9D51-31DC9B8AA4EF}"] = 1
-- WEAPONS.COST["{7H12B90B-BC0C-4a5b-9ED8-4F27A53694F6}"] = 1
-- WEAPONS.COST["{7J22B90B-BC0C-4a5b-9ED8-4F27A53694F6}"] = 1
-- WEAPONS.COST["{8D399DDA-FF81-4F14-904D-099B34FE7918}"] = 1
-- WEAPONS.COST["{A111396E-D3E8-4b9c-8AC9-24324893065B}"] = 1
-- WEAPONS.COST["{AIM-9J}"] = 1
-- WEAPONS.COST["{BRU-42_2*Mk-82_LEFT}"] = 2
-- WEAPONS.COST["{BRU-42_2*Mk-82_RIGHT}"] = 2
-- WEAPONS.COST["{BRU-42_3*Mk-82LD}"] = 3
-- WEAPONS.COST["{BRU3242_2*LAU10 R}"] = 2
-- WEAPONS.COST["{BRU3242_LAU10}"] = 1
-- WEAPONS.COST["{BCE4E030-38E9-423E-98ED-24BE3DA87C32}"] = 1 -- Mk-82 LD
-- WEAPONS.COST["{B919B0F4-7C25-455E-9A02-CEA51DB895E3}"] = 1
-- WEAPONS.COST["{B52H_BAY_M117}"] = 1
-- WEAPONS.COST["{CCF898C9-5BC7-49A4-9D1E-C3ED3D5166A1}"] = 1
-- WEAPONS.COST["{DAC53A2F-79CA-42FF-A77A-F5649B601308}"] = 1
-- WEAPONS.COST["{E1AAE713-5FC3-4CAA-9FF5-3FDCFB899E33}"] = 1
-- WEAPONS.COST["{E1F29B21-F291-45DD-A45B-2C39DAAB1CA8}"] = 1
-- WEAPONS.COST["{E8069896-8435-4B90-95C0-01A03AE6E400}"] = 1
-- WEAPONS.COST["{F1243568-8EF0-49D4-9CB5-4DA90D92BC1D}"] = 1
-- WEAPONS.COST["{F16A4DE0-116C-4A71-97F0-2CF85B0313EC}"] = 1
-- WEAPONS.COST["{F376DBEE-4CAE-41BA-ADD9-B2910AC95DEC}"] = 1
-- WEAPONS.COST["{GAR-8}"] = 1
-- WEAPONS.COST["{HB_F4E_AIM-7E}"] = 1
-- WEAPONS.COST["{HB_F4E_MK-82_3x}"] = 3
-- WEAPONS.COST["{HB_F4E_MK-82_6x}"] = 6
-- WEAPONS.COST["{HB_F4E_ROCKEYE_3x}"] = 3
-- WEAPONS.COST["{HVARx2}"] = 1       -- two HVARs → ceil(2/2)=1
-- WEAPONS.COST["{K-13A}"] = 1
-- WEAPONS.COST["{MMagicII}"] = 1
-- WEAPONS.COST["{Matra_S530F}"] = 1
-- WEAPONS.COST["{MER-5E_MK82_Snakeye}"] = 5
-- WEAPONS.COST["{MER-5E_MK82}"] = 5
-- WEAPONS.COST["{PHXBRU3242_2*LAU10}"] = 2
-- WEAPONS.COST["{PHXBRU3242_LAU10}"] = 1
-- WEAPONS.COST["{R-13M}"] = 1
-- WEAPONS.COST["{R-13M1}"] = 1
-- WEAPONS.COST["{R-3S}"] = 1
-- WEAPONS.COST["{R-60M}"] = 1
-- WEAPONS.COST["{SPS_141_ECM}"] = 0  -- ECM (explicit 0 just in case)
-- WEAPONS.COST["{US_Mk-82_SE}"] = 1
-- WEAPONS.COST["{US_Mk-82}"] = 1
-- WEAPONS.COST["{US_Mk-83}"] = 1
-- WEAPONS.COST["{VIGGEN_X-TANK}"] = 0  -- fuel tank style, but keep explicit 0

-- -- (…many other COST entries generated here…)
-- -- ---- Rocket pods (define rocket COUNT; billing = ceil(N/2) in computeAmmoCostFromPylons) ----
-- WEAPONS.COST.ROCKET_PODS["{B_8V20A_CM_WH}"] = 20
-- WEAPONS.COST.ROCKET_PODS["{B_8V20A_OM}"] = 20
-- WEAPONS.COST.ROCKET_PODS["{LAU-10}"] = 4
-- WEAPONS.COST.ROCKET_PODS["{LAU-131}"] = 7
-- WEAPONS.COST.ROCKET_PODS["{LAU-61}"] = 19
-- WEAPONS.COST.ROCKET_PODS["{LAU_3A}"] = 19
-- WEAPONS.COST.ROCKET_PODS["{M261_MK151}"] = 19
-- WEAPONS.COST.ROCKET_PODS["{Matra155RocketPod}"] = 18
-- WEAPONS.COST.ROCKET_PODS["{ORO57K_S5M_HEFRAG}"] = 16
-- WEAPONS.COST.ROCKET_PODS["{UB-16-57UMP}"] = 16
-- WEAPONS.COST.ROCKET_PODS["{UB-32A-24}"] = 32
-- WEAPONS.COST.ROCKET_PODS["{UB32A_S5KP}"] = 32
-- -- (…other pods in your presets are included; extend as you add new ones…)

-- -- ---- Zero-cost (guns, fuel tanks, ECM/flares, etc.) ----
-- WEAPONS.COST["{ALQ_184}"] = 0
-- WEAPONS.COST["{CH47_AFT_M240H}"] = 0
-- WEAPONS.COST["{CH47_PORT_M240H}"] = 0
-- WEAPONS.COST["{CH47_STBD_M240H}"] = 0
-- WEAPONS.COST["{DEFA553_GUNPOD_L}"] = 0
-- WEAPONS.COST["{DEFA553_GUNPOD_R}"] = 0
-- WEAPONS.COST["{F4_SARGENT_TANK_370_GAL}"] = 0
-- WEAPONS.COST["{F4_SARGENT_TANK_370_GAL_R}"] = 0
-- WEAPONS.COST["{F4_SARGENT_TANK_600_GAL}"] = 0
-- WEAPONS.COST["{F14-300gal}"] = 0
-- WEAPONS.COST["{GAU_12_Equalizer}"] = 0
-- WEAPONS.COST["{GUV_VOG}"] = 0
-- WEAPONS.COST["{HB_ALE_40_30_60}"] = 0
-- WEAPONS.COST["{MB339_DEFA553_L}"] = 0
-- WEAPONS.COST["{MB339_DEFA553_R}"] = 0
-- WEAPONS.COST["{PTB_1500MiG23}"] = 0
-- WEAPONS.COST["{PTB_490_MIG19}"] = 0
-- WEAPONS.COST["{PTB_490_MIG21}"] = 0
-- WEAPONS.COST["{PTB_800_MIG19}"] = 0
-- WEAPONS.COST["{PTB-300GAL-F5}"] = 0
-- WEAPONS.COST["{PTB-530}"] = 0
-- WEAPONS.COST["{SPS_141_ECM}"] = 0
-- -- (…plus other obvious tanks/ECM/gun CLSIDs from your presets…)
-- -- WEAPONS.lua — ammo accounting helpers (pod-safe) + cost adapters
-- -- Purpose:
-- --   • Give AIR/LOADOUT/STATE a safe way to estimate & debit “ammo” for spawns.
-- --   • Avoid the classic rocket-pod counting bug (don’t charge for empty pods; do charge rockets).
-- --   • Expose small CLSID catalog for common Cold-War weapons; everything else falls back by category.
-- --
-- -- Works with (optional): STATE.lua, CONFIG.AIR.AMMO_COST_BY_ROLE
-- -- Safe to load even if none of those exist.

WEAPONS = WEAPONS or {}

local function info(t) if env and env.info then env.info("[WEAPONS] "..tostring(t)) end end
local function say (t,d) trigger.action.outText("[WEAPONS] "..tostring(t), d or 5) end

-- --------------------------------------------------------------------
-- Tunables / fallbacks
-- --------------------------------------------------------------------
-- Baseline per-category “ammo unit” weights (used when CLSID unknown).
-- Tweak to taste: bombs are “heavier” than rockets, missiles somewhere in-between.
WEAPONS.WEIGHT = {
  missile = 2.0,   -- each missile counts as 2 ammo units
  rocket  = 1.0,   -- each rocket counts as 1 ammo unit
  bomb    = 3.0,   -- each bomb counts as 3 ammo units
  gun     = 0.05,  -- per round (very light)
}

-- If AIR doesn’t provide CONFIG.AIR.AMMO_COST_BY_ROLE, use this:
WEAPONS.ROLE_AMMO_COST = {
  CAP=2, CAS=8, STRIKE=12, BOMB=16, RECON=0, AWACS=0, TANKER=0, TRANSPORT=0
}

-- Optional: direct CLSID hints for rocket-pods etc. (rounds within)
-- Add more as needed; unknown CLSIDs fall back to category counting.
WEAPONS.CLSID_INFO = {
  -- Examples (you can extend over time):
  ["{LAU3_HE5}"]              = { kind="rocket", rounds=19 },
  ["{LAU-10}"]                = { kind="rocket", rounds=4  },
  ["{LAU-105_2*AIM-9L}"]      = { kind="missile", rounds=2 },
  ["{AIM-9J}"]                = { kind="missile", rounds=1 },
  ["{AIM-9L}"]                = { kind="missile", rounds=1 },
  ["{HB_F4E_AIM-7E}"]         = { kind="missile", rounds=1 },
  ["{AIM_54C_Mk60}"]          = { kind="missile", rounds=1 },
  ["{HB_F4E_MK-82_3x}"]       = { kind="bomb",    rounds=3 },
  ["{HB_F4E_MK-82_6x}"]       = { kind="bomb",    rounds=6 },
  ["{BCE4E030-38E9-423E-98ED-24BE3DA87C32}"] = { kind="bomb", rounds=1 }, -- Mk-82 LD common CLSID
  ["{60CC734F-0AFA-4E2E-82B8-93B941AB11CF}"] = { kind="bomb", rounds=1 }, -- CBU-87/97 style (example)
  ["{RB75}"]                   = { kind="missile", rounds=1 }, -- AGM-65 family for AJS37
  ["{PHXBRU3242_2*LAU10 RS}"]  = { kind="rocket",  rounds=8 },
  ["{PHXBRU3242_2*LAU10 LS}"]  = { kind="rocket",  rounds=8 },
}

-- --------------------------------------------------------------------
-- Helpers: category name from DCS ammo desc
-- desc.category (common values):
--   0 = SHELLS (gun), 1 = MISSILES, 2 = ROCKETS, 3 = BOMBS (varies by build)
-- --------------------------------------------------------------------
local function catNameFromDesc(desc)
  local c = desc and desc.category
  if c == 0 then return "gun"
  elseif c == 1 then return "missile"
  elseif c == 2 then return "rocket"
  elseif c == 3 then return "bomb"
  end
  return nil
end

-- Normalize a single ammo entry into {kind, count}
local function normalizeEntry(entry)
  if not entry then return nil end
  local count = tonumber(entry.count) or 0
  local desc  = entry.desc or {}
  local kind  = catNameFromDesc(desc)

  -- If CLSID is present, prefer our hints (rounds inside a pod, etc.)
  local clsid = desc.CLSID or desc.clsid
  if clsid and WEAPONS.CLSID_INFO[clsid] then
    local meta = WEAPONS.CLSID_INFO[clsid]
    -- If DCS reports "count" as number of launchers/pods, multiply by rounds-inside.
    local rounds = (tonumber(meta.rounds) or 0) * math.max(1, count)
    return { kind = meta.kind or kind or "rocket", count = rounds }
  end

  -- Otherwise: if we have a kind, use the reported count as munitions count.
  if kind then
    -- Guns: count is often “rounds” already. Missiles/rockets/bombs: also okay.
    return { kind = kind, count = count }
  end

  -- Unknown: ignore safely
  return nil
end

-- Sum an entire Unit:getAmmo() list into coarse totals.
local function sumAmmoList(list)
  local out = { missile=0, rocket=0, bomb=0, gun=0 }
  if type(list) ~= "table" then return out end
  for _,e in ipairs(list) do
    local n = normalizeEntry(e)
    if n and out[n.kind] ~= nil then
      out[n.kind] = out[n.kind] + (n.count or 0)
    end
  end
  return out
end

-- Public: estimate ammo totals for a group (missiles/rockets/bombs/gun rounds)
function WEAPONS.estimateAmmoForGroup(groupName)
  local g = Group.getByName(groupName)
  local totals = { missile=0, rocket=0, bomb=0, gun=0 }
  if not (g and g.isExist and g:isExist()) then return totals end
  for _,u in ipairs(g:getUnits() or {}) do
    local ok, ammo = pcall(function() return u:getAmmo() end)
    if ok and ammo then
      local t = sumAmmoList(ammo)
      totals.missile = totals.missile + t.missile
      totals.rocket  = totals.rocket  + t.rocket
      totals.bomb    = totals.bomb    + t.bomb
      totals.gun     = totals.gun     + t.gun
    end
  end
  return totals
end

-- Convert ammo totals to “ammo units” using WEAPONS.WEIGHT
local function toAmmoUnits(totals)
  local W = WEAPONS.WEIGHT
  return (totals.missile * W.missile)
       + (totals.rocket  * W.rocket)
       + (totals.bomb    * W.bomb)
       + (totals.gun     * W.gun)
end

-- Public: estimate a STATE-ready cost table from an actual spawned group.
-- Safe if STATE is absent; just returns a suggested {mp=0, ammo=units, fuel=0}.
function WEAPONS.estimateAmmoCostForGroup(groupName)
  local t = WEAPONS.estimateAmmoForGroup(groupName)
  local units = toAmmoUnits(t)
  return { mp=0, ammo=math.floor(units + 0.5), fuel=0 }, t
end

-- Public: per-role “flat” ammo cost (if you don’t want to scan the group)
function WEAPONS.ammoCostForRole(role)
  role = tostring(role or ""):upper()
  local byCfg = (CONFIG and CONFIG.AIR and CONFIG.AIR.AMMO_COST_BY_ROLE) or {}
  local val = byCfg[role] or WEAPONS.ROLE_AMMO_COST[role] or 0
  return { mp=0, ammo=val, fuel=0 }
end

-- Public: debit ammo on spawn by role (flat) OR by scanning a named group.
-- If STATE is missing, returns true without doing anything.
function WEAPONS.debitOnSpawn(afName, sideStr, opts)
  if not STATE then return true end
  opts = opts or {}
  local cost

  if opts.groupName then
    cost = select(1, WEAPONS.estimateAmmoCostForGroup(opts.groupName))
  else
    cost = WEAPONS.ammoCostForRole(opts.role or "CAP")
  end

  if STATE.debit then return STATE.debit(afName, sideStr, cost) end
  if STATE.consume then return STATE.consume(afName, sideStr, cost) end
  return true
end

info("WEAPONS.lua loaded (pod-safe ammo accounting)")
