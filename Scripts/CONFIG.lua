-- CONFIG.lua — Central tuning for Operation Cold-War Breach (aligned with new modules)

CONFIG = CONFIG or {}

---------------------------------------------------------------------
-- Admin
---------------------------------------------------------------------
CONFIG.ADMIN_MENU = false   -- simple F10 admin menu (debug toggles)

---------------------------------------------------------------------
-- Canonical Airfield List (names must match Mission Editor & TERRAIN)
---------------------------------------------------------------------
CONFIG.AIRFIELDS = {
  "Bodo","Kallax","Kemi Tornio","Evenes","Andoya","Kiruna","Vidsel","Kuusamo",
  "Poduzhemye","Afrikanda","Olenya","Severomorsk-1","Severomorsk-3",
  "Murmansk International","Kilpyavr","Koshka Yavr","Ivalo","Kittila","Alta",
  "Banak","Vuojarvi","Bardufoss","Jokkmokk","Rovaniemi","Alakurtti",
  "Monchegorsk","Luostari Pechenga","Kirkenes","Sodankyla","Enontekio",
  "Kalevala","Hosio"
}

---------------------------------------------------------------------
-- Coalition / Country mapping (used by spawners)
---------------------------------------------------------------------
CONFIG.COUNTRY = {
  BLUE = country.id.USA,
  RED  = country.id.RUSSIA,
}

---------------------------------------------------------------------
-- STATE / Economy
---------------------------------------------------------------------
CONFIG.STATE = {
  tick_sec     = 120,                                         -- income tick period
  HUB_GEN      = { mp=9,  ammo=45, fuel=60 },                -- per tick (hubs)
  BASE_GEN     = { mp=3,  ammo=15, fuel=20 },                -- per tick (non-hubs)
  DEFAULT_CAP  = { mp=5000, ammo=8000, fuel=12000 },         -- default per-AF caps

  -- Hubs earn more (single source of truth; TERRAIN.init syncs flags from here)
  HUBS = { "Bodo","Kallax","Kemi Tornio","Severomorsk-1","Severomorsk-3","Poduzhemye" },

  -- Start stocks applied to ALL AFs unless overridden below
  SEED_DEFAULT = { mp=800, ammo=1500, fuel=2500 },

  -- Optional per-AF overrides
  SEED = {
    -- ["Bardufoss"] = { init = { mp=1000, ammo=1800, fuel=3000 }, cap = { mp=6000, ammo=9000, fuel=14000 } },
  },

  debug = false,
}

---------------------------------------------------------------------
-- MARK (map overlays)
---------------------------------------------------------------------
CONFIG.MARK = {
  REFRESH_SEC = 30,  -- how often MARK.lua refreshes labels
  debug = false,
}

---------------------------------------------------------------------
-- TERRAIN
---------------------------------------------------------------------
CONFIG.TERRAIN = {
  -- placeholder for future terrain/ownership scan tuning
}

---------------------------------------------------------------------
-- GROUND (waves, costs, AAA replenish)
---------------------------------------------------------------------
CONFIG.GROUND = {
  COUNTRY = { BLUE = CONFIG.COUNTRY.BLUE, RED = CONFIG.COUNTRY.RED },

  -- Global live cap
  MAX_ACTIVE_GROUPS  = 30,

  -- Wave sequencing (used by GROUND.lua)
  SEQUENCE        = { "AAA","TANK","ARTILLERY" },  -- order per route/side
  SEQ_DELAY_MIN   = 20,                            -- gap between spawns (minutes)
  SEQ_DELAY_SEC   = 5,                           -- min gap between spawns (seconds)
  ROUTE_STAGGER_SEC = 1,

  -- Loss & burnout handling
  LOSS_DESPAWN_FRAC   = 0.70,   -- if group lost ≥70% -> burn then despawn
  BURNOUT_DESPAWN_SEC = 300,    -- burn window = 5 min

  -- Optional spawn costs (tweak to taste; low defaults to keep flow moving)
  COST = {
    TANK      = { mp=60, ammo=30, fuel=120 },
    ARTILLERY = { mp=50, ammo=40, fuel=80  },
    AAA       = { mp=30, ammo=20, fuel=40  },   -- charged at truck stage
  },

  -- AAA ammo replenish trigger (referenced by GROUND/TRANSPORT)
  AAA_REPLENISH_THRESHOLD = 0.20,     -- when <20% ammo -> request resupply

  -- Ferry integration knobs (also used by FERRY.lua)
  FERRY_DWELL_SEC    = 30,            -- must dwell inside FERRY_* zone
  FERRY_COOLDOWN_SEC = 1200,          -- per-pair cooldown (20 min)

  debug = true,
}

-- Optional: multi-leg ferry chains (keys "From->To" -> list of { "FERRY_X_A","FERRY_X_B" } pairs)
-- CONFIG.FERRY_ROUTES = {
--   ["Bodo->Evenes"] = { {"FERRY_BE_A","FERRY_BE_B"} },
-- }

---------------------------------------------------------------------
-- AIR (AI air wing manager) – aligns with AIR.lua expectations
---------------------------------------------------------------------
CONFIG.AIR = {
  ENABLED           = true,
  TICK              = 60,                    -- upkeep interval (sec)

  SPAWN = {
    ORDER = { "CAP","CAS","STRIKE","BOMB","RECON","AWACS","TANKER","TRANSPORT" },  -- spawn priority
    INITIAL_BURST = {
      ENABLED = true,  -- spawn initial burst on mission start
      DURATION = 600, -- over this many seconds
      INTERVAL = 90,  -- every X seconds
    },
    SUPPORT_DELAY = 420, -- delay before spawning support roles (sec)
    MAX_ACTIVE = { AWACS = 1, TANKER = 1,},
  },

  -- Desired groups per AF (per side) maintained on active fronts
  ROLE_COUNTS = {
    CAP=3, CAS=2, STRIKE=1, BOMB=1, RECON=1, AWACS=1, TANKER=1, TRANSPORT=0
  },

  -- Global cap per side (total concurrent AI air groups)
  MAX_ACTIVE_GROUPS = 12,

  -- Lifecycles (minutes)
  PATROL_MIN        = 20,                   -- soft RTB/despawn after this
  MISSION_MIN       = 45,                   -- hard stop after this
  RESPAWN_DELAY_MIN = 10,                   -- delay before respawning a role

  -- Spawn posture per role (cold starts for support by default)
  SPAWN_COLD_ROLES = { AWACS=true, TANKER=true, TRANSPORT=true },

  -- Economy helpers (optional, improves STATE cost accuracy)
  CREW_BY_TYPE = {
    ["F-4E-45MC"]=2, ["MiG-23MLD"]=1, ["A-10A"]=1, ["Su-25T"]=1, ["C-130"]=6, ["B-52H"]=10, ["An-30M"]=5,
    ["E-3A"]=8, ["A-50"]=10, ["KC-135"]=5, ["IL-78M"]=7,
    ["CH-47Fbl1"]=3, ["Mi-8MT"]=3,
  },
  FUEL_GAL_BY_TYPE = {
    ["F-4E-45MC"]=2600, ["MiG-23MLD"]=3000, ["A-10A"]=1100, ["Su-25T"]=1000, ["C-130"]=8000, ["B-52H"]=15000, ["An-30M"]=5000,
    ["E-3A"]=13000, ["A-50"]=15000, ["KC-135"]=16000, ["IL-78M"]=16500,
    ["CH-47Fbl1"]=1100, ["Mi-8MT"]=600,
  },
  AMMO_COST_BY_ROLE = { CAP=2, CAS=8, STRIKE=12, BOMB=16, RECON=0, AWACS=0, TANKER=0, TRANSPORT=0 },

  -- Aircraft type selection per side/role (falls back to UNITS.lua if missing)
  TYPE_BY_ROLE = {
    BLUE = { CAP="F-4E-45MC", CAS="A-10A", STRIKE="B-52H", BOMB="B-52H", RECON="C-130", AWACS="E-3A", TANKER="KC-135", TRANSPORT="CH-47Fbl1" },
    RED  = { CAP="MiG-23MLD", CAS="Su-25T", STRIKE="Tu-22M3", BOMB="Tu-22M3", RECON="An-30M", AWACS="A-50", TANKER="IL-78M", TRANSPORT="Mi-8MT" },
  },

  -- Loadout mapping (role -> LOADOUT name) used by LOADOUT.lua (optional)
  LOADOUTS = {
    CAP       = "Air2AirFull",
    STRIKE    = "BombFull",
    CAS       = "AGRockets",
    BOMB      = "BombFull",
    RECON     = nil,
    AWACS     = nil,
    TANKER    = nil,
    TRANSPORT = "Troops",
  },

  -- TANKER racetrack parameters (used if role present)
  TANKER_RACETRACK_LEN = 18000,
  TANKER_RACETRACK_HDG = 90,

  debug = false,
}

---------------------------------------------------------------------
-- TRANSPORT (auto logistics: trucks vs helos)
---------------------------------------------------------------------
CONFIG.TRANSPORT = {
  scan_interval_sec       = 60,

  -- Range / radii (meters)
  TRUCK_MAX_RANGE_M       = 120000,   -- ≤ this -> trucks; otherwise helicopters
  ARRIVAL_RADIUS_TRUCK_M  = 30,       -- ~100 ft success radius
  ARRIVAL_RADIUS_HELO_M   = 350,      -- meters; helos must LAND within this to credit

  -- Composition & failure
  TRUCK_CONVOY_COUNT      = 10,
  HELO_FLIGHT_COUNT       = 2,
  FAILURE_LOSS_FRACTION   = 0.70,

  -- Timers
  TRUCK_DWELL_SEC         = 120,      -- trucks must stay 2 minutes
  TRUCK_FAIL_RETRY_SEC    = 3600,     -- retry after 1 hour on failure
  HELO_SHUTDOWN_DWELL_SEC = 300,      -- helos: land time before credit
  HELO_FAIL_RETRY_SEC     = 3600,

  HUB_THRESHOLD_FRACTION  = 0.50,     -- donor AF must be >50% stocked

  -- Delivery credit per completed run
  DELIVER_TRUCK = { mp=10, ammo=20,  fuel=100 },
  DELIVER_HELO  = { mp=30, ammo=50,  fuel=500 },

  debug = false,
}

---------------------------------------------------------------------
-- PICKUP (helo troop/vehicle pickup & deploy)
---------------------------------------------------------------------
CONFIG.PICKUP = {
  debug = false,

  -- What each thing costs if UNITS.lua doesn’t provide a per-type cost:
  COST = {
    INF_SQUAD = { mp = 5,  ammo = 0,  fuel = 0  },   -- per squad
    VEHICLE   = { mp = 15, ammo = 20, fuel = 30 },   -- generic vehicle fallback
  },

  -- Vehicle pool per side (used when UNITS doesn’t have a specific cost/type mapping)
  VEHICLE_TYPES = {
    BLUE = { "M-113", "M-60", "L118_Unit" },
    RED  = { "BRDM-2", "BMP-2", "M2A1_105" },
  },

  -- Idle/despawn behavior for deployed cargo
  IDLE_GRACE_SEC   = 600,   -- 10 min: start treating as idle after this
  IDLE_DESPAWN_SEC = 1800,  -- 30 min: despawn if still idle
  MOVE_CHECK_SEC   = 30,    -- polling interval for idle watcher
}

---------------------------------------------------------------------
-- NAVAL
---------------------------------------------------------------------
CONFIG.NAVAL = {
  MAX_ACTIVE_PER_ROUTE   = 3,
  RESPAWN_COOLDOWN_SEC   = 1800,     -- 30 min
  CATASTROPHIC_LOSS_FRAC = 0.60,     -- scuttle & cooldown if ≥60% lost
  debug = false,
  -- Optional TEMPLATES / COST / STARTUP_FLEETS can go here
}

---------------------------------------------------------------------
-- SIDEMISSIONS (F10 quick tasks)
---------------------------------------------------------------------
CONFIG.SIDEMISSIONS = {
  MAX_MISSION_RANGE_M = 1852000, -- 1000 nm
  BUBBLE_RADIUS_M     = 3000,
  SCORE_PER_KILL      = 5,
  INTERCEPT_RAID_SIZE = 2,
  AUTO_EXPIRE_MIN     = 45,
  debug = false,
}

---------------------------------------------------------------------
-- RESTRICT (player slot policy)
---------------------------------------------------------------------
-- ACTION_MODE: "WARN" = warn-only; "DESTROY" = kill violators
CONFIG.RESTRICT = {
  ACTION_MODE = "WARN",
  debug = false,
}

---------------------------------------------------------------------
-- Bootstrap (used by OPERATIONINIT.lua if present)
---------------------------------------------------------------------
CONFIG.BOOTSTRAP = {
  AIR = {
    BLUE = { from="Bodo",   roles={"CAP","CAS"} },
    RED  = { from="Evenes", roles={"CAP"} },
  },
}

pcall(function() trigger.action.outText("CONDIFG.lua LOADED...).", 5) end)
return CONFIG
