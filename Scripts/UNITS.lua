-- UNITS = UNITS or {}

-- -- Manpower/Fuel/Ammo cost per unit type (add as you go)
-- UNITS.COST = {
--   -- BLUE – Fighters / Strike
--   ["A-10A"]         = { mp = 20, ammo = 0, fuel = 0 },
--   ["AJS37"]         = { mp = 20, ammo = 0, fuel = 0 },
--   ["AV8BNA"]        = { mp = 20, ammo = 0, fuel = 0 },
--   ["F-14A-135-GR"]  = { mp = 20, ammo = 0, fuel = 0 },
--   ["F-14B"]         = { mp = 20, ammo = 0, fuel = 0 },
--   ["F-15C"]         = { mp = 20, ammo = 0, fuel = 0 },
--   ["F-16A"]         = { mp = 20, ammo = 0, fuel = 0 },
--   ["F-5E-3"]        = { mp = 15, ammo = 0, fuel = 0 },
--   ["F-86F Sabre"]   = { mp = 12, ammo = 0, fuel = 0 },
--   ["F4U-1D"]        = { mp = 12, ammo = 0, fuel = 0 },
--   ["FA-18C_hornet"] = { mp = 20, ammo = 0, fuel = 0 },
--   ["F-4E-45MC"]     = { mp = 20, ammo = 0, fuel = 0 },
--   ["M-2000C"]       = { mp = 20, ammo = 0, fuel = 0 },
--   ["MB-339A"]       = { mp = 12, ammo = 0, fuel = 0 },

--   -- RED – Fighters / Strike
--   ["L-39C"]         = { mp = 12, ammo = 0, fuel = 0 },
--   ["MiG-19P"]       = { mp = 15, ammo = 0, fuel = 0 },
--   ["MiG-21Bis"]     = { mp = 15, ammo = 0, fuel = 0 },
--   ["MiG-23MLA"]     = { mp = 18, ammo = 0, fuel = 0 },
--   ["MiG-23MLD"]     = { mp = 18, ammo = 0, fuel = 0 },
--   ["MiG-29A"]       = { mp = 20, ammo = 0, fuel = 0 },
--   ["MiG-29G"]       = { mp = 20, ammo = 0, fuel = 0 },
--   ["MiG-31"]        = { mp = 22, ammo = 0, fuel = 0 },
--   ["Su-25T"]        = { mp = 20, ammo = 0, fuel = 0 },
--   ["Su-27"]         = { mp = 20, ammo = 0, fuel = 0 },

--   -- BLUE – Bombers / Support
--   ["B-52H"]         = { mp = 40, ammo = 0, fuel = 0 },
--   ["KC-135"]        = { mp = 25, ammo = 0, fuel = 0 },
--   ["KC-135MPRS"]    = { mp = 25, ammo = 0, fuel = 0 },
--   ["E-3A"]          = { mp = 28, ammo = 0, fuel = 0 },
--   ["E-2C"]          = { mp = 24, ammo = 0, fuel = 0 },
--   ["C-130"]         = { mp = 15, ammo = 0, fuel = 0 },

--   -- RED – Bombers / Support
--   ["Tu-22M3"]       = { mp = 35, ammo = 0, fuel = 0 },
--   ["IL-78M"]        = { mp = 25, ammo = 0, fuel = 0 },
--   ["A-50"]          = { mp = 28, ammo = 0, fuel = 0 },
--   ["An-30M"]        = { mp = 14, ammo = 0, fuel = 0 },
--   ["IL-76MD"]       = { mp = 18, ammo = 0, fuel = 0 },

--   -- HELICOPTERS
--   ["UH-1H"]         = { mp = 10, ammo = 0, fuel = 0 },
--   ["CH-47D"]        = { mp = 15, ammo = 0, fuel = 0 },
--   ["CH-47Fbl1"]     = { mp = 15, ammo = 0, fuel = 0 },
--   ["Mi-8MT"]        = { mp = 12, ammo = 0, fuel = 0 },
--   ["Mi-24P"]        = { mp = 15, ammo = 0, fuel = 0 },

--   --------------------------------------------------------------------
--   -- GROUND UNITS
--   --------------------------------------------------------------------

--   -- BLUE – Air Defence
--   ["FPS-117 ECS"]                = { mp = 12, ammo = 5, fuel = 0 },
--   ["FPS-117"]                    = { mp = 12, ammo = 5, fuel = 0 },
--   ["FPS-117 Dome"]               = { mp = 12, ammo = 5, fuel = 0 },
--   ["Soldier stinger"]            = { mp = 2,  ammo = 2, fuel = 0 },
--   ["Stinger comm"]               = { mp = 2,  ammo = 2, fuel = 0 },
--   ["Hawk ln"]                    = { mp = 6,  ammo = 6, fuel = 0 },
--   ["Hawk pcp"]                   = { mp = 8,  ammo = 8, fuel = 0 },
--   ["Hawk sr"]                    = { mp = 8,  ammo = 8, fuel = 0 },
--   ["Hawk tr"]                    = { mp = 8,  ammo = 8, fuel = 0 },
--   ["Hawk cwar"]                  = { mp = 6,  ammo = 6, fuel = 0 },
--   ["Patriot cp"]                 = { mp = 6,  ammo = 6, fuel = 0 },
--   ["Roland ADS"]                 = { mp = 12, ammo = 10, fuel = 0 },
--   ["Roland Radar"]               = { mp = 10, ammo = 8,  fuel = 0 },
--   ["Vulcan"]                     = { mp = 10, ammo = 8,  fuel = 0 },
--   ["M48 Chaparral"]              = { mp = 6,  ammo = 6,  fuel = 0 },

--   -- RED – Air Defence
--   ["SON_9"]                       = { mp = 1, ammo = 0, fuel = 5 },
--   ["KS-19"]                       = { mp = 2, ammo = 2, fuel = 0 },
--   ["S-60_Type59_Artillery"]       = { mp = 2, ammo = 2, fuel = 0 },
--   ["ZU-23 Emplacement Closed"]    = { mp = 3, ammo = 5, fuel = 0 },
--   ["ZU-23 Emplacement"]           = { mp = 3, ammo = 5, fuel = 0 },
--   ["Ural-375 ZU-23"]              = { mp = 4, ammo = 5, fuel = 2 },
--   ["generator_5i57"]              = { mp = 1, ammo = 0, fuel = 1 },
--   ["SA-18 Igla manpad"]           = { mp = 1, ammo = 2, fuel = 0 },
--   ["SA-18 Igla comm"]             = { mp = 1, ammo = 2, fuel = 0 },
--   ["Dog Ear radar"]               = { mp = 2, ammo = 5, fuel = 2 },
--   ["S-300PS 64H6E sr"]            = { mp = 5, ammo = 0, fuel = 5},
--   ["S-300PS 54K6 cp"]             = { mp = 5, ammo = 0, fuel = 5},
--   ["S-300PS 40B6MD sr"]           = { mp = 5, ammo = 0, fuel = 5},
--   ["S-300PS 40B6M tr"]            = { mp = 5, ammo = 0, fuel = 5},
--   ["S-300PS 5H63C 30H6_tr"]       = { mp = 5, ammo = 0, fuel = 5},
--   ["S-300PS 5P85C ln"]            = { mp = 5, ammo = 10, fuel = 5},
--   ["S-300PS 5P85D ln"]            = { mp = 5, ammo = 10, fuel = 5},
--   ["S-300PS 40B6MD sr_19J6"]      = { mp = 5, ammo = 5, fuel = 5},
--   ["SNR_75V"]                     = { mp = 5, ammo = 5, fuel = 5},  
--   ["S_75M_Volhov"]                = { mp = 2,  ammo = 5, fuel = 0 },
--   ["p-19 s-125 sr"]               = { mp = 2,  ammo = 0, fuel = 3 },
--   ["5p73 s-125 ln"]               = { mp = 5, ammo = 10, fuel = 0 },
--   ["snr s-125 tr"]                = { mp = 5, ammo = 0, fuel = 0 },
--   ["S-200_Launcher"]              = { mp = 5, ammo = 10, fuel = 0 },
--   ["RPC_5N62V"]                   = { mp = 5, ammo = 0, fuel = 0 },
--   ["RLS_19J6"]                    = { mp = 5, ammo = 0, fuel = 0 },
--   ["Kub 2P25 ln"]                 = { mp = 5, ammo = 10, fuel = 5 },
--   ["Kub 1S91 str"]                = { mp = 5,  ammo = 0,  fuel = 8 },
--   ["Osa 9A33 ln"]                 = { mp = 5,  ammo = 10,  fuel = 5 },
--   ["Strela-1 9P31"]               = { mp = 3,  ammo = 10,  fuel = 3 },
--   ["ZSU-23-4 Shilka"]             = { mp = 6,  ammo = 12,  fuel = 6 },
--   ["ZSU_57_2"]                    = { mp = 5,  ammo = 12,  fuel = 6 },

--   -- BLUE – Armor
--   ["AAV7"]                         = { mp = 5,  ammo = 5,  fuel = 5 },
--   ["M-113"]                         = { mp = 5,  ammo = 5,  fuel = 5 },
--   ["M-60"]                        = { mp = 6, ammo = 10,  fuel = 6 },

--   -- RED – Armor
--   ["BTR-D"]                      = { mp = 6,  ammo = 4,  fuel = 5 },
--   ["MTLB"]                       = { mp = 5,  ammo = 4,  fuel = 5 },
--   ["BMD-1"]                       = { mp = 6,  ammo = 5,  fuel = 5 },
--   ["BMP-1"]                       = { mp = 6,  ammo = 5,  fuel = 5 },
--   ["BMP-2"]                       = { mp = 6,  ammo = 6,  fuel = 5 },
--   ["PT-76"]                        = { mp = 6,  ammo = 6,  fuel = 6 },
--   ["T-55"]                      = { mp = 6, ammo = 12,  fuel = 6 },
--   ["BRDM-2"]                      = { mp = 5,  ammo = 4,  fuel = 4 },

--   -- BLUE – Artillery
--   ["L118_Unit"]                    = { mp = 5,  ammo = 12, fuel = 0 },
--   ["M-109"]                        = { mp = 10,  ammo = 20, fuel = 10 },

--   -- RED – Artillery
--   ["M2A1_105"]                     = { mp = 5, ammo = 12, fuel = 0 },
--   ["Grad_URAL"]                    = { mp = 8,  ammo = 15, fuel = 4 },
--   ["SAU 2-C9"]                     = { mp = 5,  ammo = 12,  fuel = 5 },
--   ["SAU Akatsia"]                  = { mp = 10,  ammo = 20,  fuel = 10 },

--   -- BLUE - Infantry
--   ["Soldier M4"]                   = { mp = 1, ammo = 1, fuel = 0},
--   ["Soldier M249"]                 = { mp = 1, ammo = 2, fuel = 0},

--   -- RED - Infantry
--   ["Paratrooper AKS-74"]           = { mp = 1, ammo = 1, fuel = 0},
--   ["Paratrooper RPG-16"]           = { mp = 1, ammo = 3, fuel = 0},

--   -- BLUE - Unarmed/Transports
--   ["M 818"]                        = { mp = 1, ammo = 5, fuel = 5},

--   -- RED - Unarmed/Transports
--   ["ATMZ-5"]                       = { mp = 1, ammo = 0, fuel = 10},
--   ["Ural-4320T"]                   = { mp = 1, ammo = 10, fuel = 0},

--   -- BLUE SHIPS
--   ["PERRY"]                         = { mp = 50, ammo = 50, fuel = 50 },
--   ["LST_Mk2"]                        = { mp = 40, ammo = 40, fuel = 40 },
--   ["USS_Samuel_Chase"]              = { mp = 60, ammo = 60, fuel = 60 },
--   ["LHA_Tarawa"]                     = { mp = 60, ammo = 60, fuel = 60 },
--   ["Essex"]                         = { mp = 45, ammo = 45, fuel = 45 },
--   ["CVN_72"]                         = { mp = 55, ammo = 55, fuel = 55 },
--   ["santafe"]                         = { mp = 55, ammo = 55, fuel = 55 },

--   -- SHIPS for both sides
--   ["Seawise_Giant"]                  = { mp = 50, ammo = 50, fuel = 50 },
--   ["Ship_Tilde_Supply"]                 = { mp = 40, ammo = 40, fuel = 40 },
--   ["HandyWind"]                         = { mp = 55, ammo = 55, fuel = 55 },
--   ["speedboat"]                         = { mp = 55, ammo = 55, fuel = 55 },

--   -- RED SHIPS
--   ["ELNYA"]                  = { mp = 50, ammo = 50, fuel = 50 },
--   ["KILO"]                  = { mp = 50, ammo = 50, fuel = 50 },
--   ["BDK-775"]                  = { mp = 50, ammo = 50, fuel = 50 },
--   ["REZKY"]                  = { mp = 50, ammo = 50, fuel = 50 },
--   ["KUZNECOW"]                  = { mp = 50, ammo = 50, fuel = 50 },
--   ["Dry-cargo ship-2"]                  = { mp = 50, ammo = 50, fuel = 50 },
--   ["Dry-cargo ship-1"]                  = { mp = 50, ammo = 50, fuel = 50 },
-- }
-- -- UNITS.lua — unified catalogs + per-type costs + helpers
-- -- Used by: GROUND, NAVAL, TRANSPORT, PICKUP (and optional AIR fallbacks)
-- --
-- -- What’s here:
-- --   • UNITS.COST[typeName]         -> { mp=, ammo=, fuel= }
-- --   • UNITS.costFor(typeName)      -> lookup helper (nil-safe)
-- --   • UNITS.GROUND[side].<ROLE>    -> role catalogs: TANK, ARTILLERY, AAA, AAA_TRUCK, VEHICLE
-- --   • UNITS.NAVAL[side].<ROLE>     -> PATROL, STRIKE, SHORE
-- --   • UNITS.TRANSPORT[side].TRUCK/HELO
-- --   • UNITS.pick(side, domain, role) -> pick a random type (nil-safe)
-- --
-- -- Side strings are "BLUE" or "RED".

UNITS = UNITS or {}

local function pick(t) if type(t)=="table" and #t>0 then return t[math.random(#t)] end end
local function info(t) if env and env.info then env.info("[UNITS] "..tostring(t)) end end

----------------------------------------------------------------------
-- Costs (AIR / GROUND / NAVAL / TRANSPORT) — extend as you go
----------------------------------------------------------------------
UNITS.COST = {
  -- BLUE — Fighters / Strike / Support
  ["A-10A"]         = { mp=20, ammo=0, fuel=0 },
  ["AJS37"]         = { mp=20, ammo=0, fuel=0 },
  ["AV8BNA"]        = { mp=20, ammo=0, fuel=0 },
  ["F-14A-135-GR"]  = { mp=20, ammo=0, fuel=0 },
  ["F-14B"]         = { mp=20, ammo=0, fuel=0 },
  ["F-15C"]         = { mp=20, ammo=0, fuel=0 },
  ["F-16A"]         = { mp=20, ammo=0, fuel=0 },
  ["F-5E-3"]        = { mp=15, ammo=0, fuel=0 },
  ["F-86F Sabre"]   = { mp=12, ammo=0, fuel=0 },
  ["F4U-1D"]        = { mp=12, ammo=0, fuel=0 },
  ["FA-18C_hornet"] = { mp=20, ammo=0, fuel=0 },
  ["F-4E-45MC"]     = { mp=20, ammo=0, fuel=0 },
  ["M-2000C"]       = { mp=20, ammo=0, fuel=0 },
  ["MB-339A"]       = { mp=12, ammo=0, fuel=0 },
  ["B-52H"]         = { mp=40, ammo=0, fuel=0 },
  ["KC-135"]        = { mp=25, ammo=0, fuel=0 },
  ["KC-135MPRS"]    = { mp=25, ammo=0, fuel=0 },
  ["E-3A"]          = { mp=28, ammo=0, fuel=0 },
  ["E-2C"]          = { mp=24, ammo=0, fuel=0 },
  ["C-130"]         = { mp=15, ammo=0, fuel=0 },

  -- RED — Fighters / Strike / Support
  ["L-39C"]         = { mp=12, ammo=0, fuel=0 },
  ["MiG-19P"]       = { mp=15, ammo=0, fuel=0 },
  ["MiG-21Bis"]     = { mp=15, ammo=0, fuel=0 },
  ["MiG-23MLA"]     = { mp=18, ammo=0, fuel=0 },
  ["MiG-23MLD"]     = { mp=18, ammo=0, fuel=0 },
  ["MiG-29A"]       = { mp=20, ammo=0, fuel=0 },
  ["MiG-29G"]       = { mp=20, ammo=0, fuel=0 },
  ["MiG-31"]        = { mp=22, ammo=0, fuel=0 },
  ["Su-25T"]        = { mp=20, ammo=0, fuel=0 },
  ["Su-27"]         = { mp=20, ammo=0, fuel=0 },
  ["Tu-22M3"]       = { mp=35, ammo=0, fuel=0 },
  ["IL-78M"]        = { mp=25, ammo=0, fuel=0 },
  ["A-50"]          = { mp=28, ammo=0, fuel=0 },
  ["An-30M"]        = { mp=14, ammo=0, fuel=0 },
  ["IL-76MD"]       = { mp=18, ammo=0, fuel=0 },

  -- HELICOPTERS
  ["UH-1H"]         = { mp=10, ammo=0, fuel=0 },
  ["CH-47D"]        = { mp=15, ammo=0, fuel=0 },
  ["CH-47Fbl1"]     = { mp=15, ammo=0, fuel=0 },
  ["Mi-8MT"]        = { mp=12, ammo=0, fuel=0 },
  ["Mi-24P"]        = { mp=15, ammo=0, fuel=0 },

  --------------------------------------------------------------------
  -- GROUND — Air Defence (BLUE)
  --------------------------------------------------------------------
  ["FPS-117 ECS"]             = { mp=12, ammo=5, fuel=0 },
  ["FPS-117"]                 = { mp=12, ammo=5, fuel=0 },
  ["FPS-117 Dome"]            = { mp=12, ammo=5, fuel=0 },
  ["Soldier stinger"]         = { mp=2,  ammo=2, fuel=0 },
  ["Stinger comm"]            = { mp=2,  ammo=2, fuel=0 },
  ["Hawk ln"]                 = { mp=6,  ammo=6, fuel=0 },
  ["Hawk pcp"]                = { mp=8,  ammo=8, fuel=0 },
  ["Hawk sr"]                 = { mp=8,  ammo=8, fuel=0 },
  ["Hawk tr"]                 = { mp=8,  ammo=8, fuel=0 },
  ["Hawk cwar"]               = { mp=6,  ammo=6, fuel=0 },
  ["Patriot cp"]              = { mp=6,  ammo=6, fuel=0 },
  ["Roland ADS"]              = { mp=12, ammo=10, fuel=0 },
  ["Roland Radar"]            = { mp=10, ammo=8,  fuel=0 },
  ["Vulcan"]                  = { mp=10, ammo=8,  fuel=0 },
  ["M48 Chaparral"]           = { mp=6,  ammo=6,  fuel=0 },

  -- GROUND — Air Defence (RED)
  ["SON_9"]                    = { mp=1,  ammo=0, fuel=5 },
  ["KS-19"]                    = { mp=2,  ammo=2, fuel=0 },
  ["S-60_Type59_Artillery"]    = { mp=2,  ammo=2, fuel=0 },
  ["ZU-23 Emplacement Closed"] = { mp=3,  ammo=5, fuel=0 },
  ["ZU-23 Emplacement"]        = { mp=3,  ammo=5, fuel=0 },
  ["Ural-375 ZU-23"]           = { mp=4,  ammo=5, fuel=2 },
  ["generator_5i57"]           = { mp=1,  ammo=0, fuel=1 },
  ["SA-18 Igla manpad"]        = { mp=1,  ammo=2, fuel=0 },
  ["SA-18 Igla comm"]          = { mp=1,  ammo=2, fuel=0 },
  ["Dog Ear radar"]            = { mp=2,  ammo=5, fuel=2 },
  ["S-300PS 64H6E sr"]         = { mp=5,  ammo=0, fuel=5 },
  ["S-300PS 54K6 cp"]          = { mp=5,  ammo=0, fuel=5 },
  ["S-300PS 40B6MD sr"]        = { mp=5,  ammo=0, fuel=5 },
  ["S-300PS 40B6M tr"]         = { mp=5,  ammo=0, fuel=5 },
  ["S-300PS 5H63C 30H6_tr"]    = { mp=5,  ammo=0, fuel=5 },
  ["S-300PS 5P85C ln"]         = { mp=5,  ammo=10, fuel=5 },
  ["S-300PS 5P85D ln"]         = { mp=5,  ammo=10, fuel=5 },
  ["RLS_19J6"]                 = { mp=5,  ammo=0,  fuel=5 },
  ["SNR_75V"]                  = { mp=3,  ammo=0,  fuel=3 },
  ["S_75M_Volhov"]             = { mp=3,  ammo=0,  fuel=3 },
  ["p-19 s-125 sr"]            = { mp=3,  ammo=0,  fuel=3 },
  ["5p73 s-125 ln"]            = { mp=3,  ammo=8,  fuel=3 },
  ["snr s-125 tr"]             = { mp=3,  ammo=0,  fuel=3 },
  ["S-200_Launcher"]           = { mp=5,  ammo=10, fuel=6 },
  ["RPC_5N62V"]                = { mp=4,  ammo=0,  fuel=4 },
  ["Kub 2P25 ln"]              = { mp=4,  ammo=6,  fuel=3 },
  ["Kub 1S91 str"]             = { mp=4,  ammo=0,  fuel=3 },
  ["Osa 9A33 ln"]              = { mp=4,  ammo=6,  fuel=3 },
  ["Strela-1 9P31"]            = { mp=3,  ammo=4,  fuel=2 },
  ["ZSU-23-4 Shilka"]          = { mp=5,  ammo=8,  fuel=4 },
  ["ZSU_57_2"]                 = { mp=5,  ammo=8,  fuel=4 },

  -- GROUND — Armor / APC / Tanks (sample costs)
  ["AAV7"]     = { mp=10, ammo=2, fuel=6 },
  ["M-113"]    = { mp=8,  ammo=2, fuel=5 },
  ["M-60"]     = { mp=16, ammo=6, fuel=10 },
  ["PT-76"]    = { mp=12, ammo=5, fuel=8 },
  ["BMP-1"]    = { mp=14, ammo=5, fuel=9 },
  ["BMP-2"]    = { mp=14, ammo=6, fuel=9 },
  ["BTR-D"]    = { mp=10, ammo=3, fuel=7 },
  ["MTLB"]     = { mp=10, ammo=3, fuel=7 },
  ["BMD-1"]    = { mp=12, ammo=4, fuel=8 },
  ["T-55"]     = { mp=16, ammo=6, fuel=10 },
  ["BRDM-2"]   = { mp=8,  ammo=2, fuel=6 },

  -- GROUND — Artillery (sample costs)
  ["L118_Unit"] = { mp=8,  ammo=6, fuel=2 },
  ["M-109"]     = { mp=14, ammo=10, fuel=8 },
  ["M2A1_105"]  = { mp=6,  ammo=5,  fuel=2 },
  ["Grad_URAL"] = { mp=10, ammo=12, fuel=8 },

  -- Trucks (transport / AAA-truck base)
  ["M 818"]       = { mp=4, ammo=0, fuel=2 },
  ["Ural-4320T"]  = { mp=4, ammo=0, fuel=2 },
  ["Ural-375"]    = { mp=4, ammo=0, fuel=2 },
}

function UNITS.costFor(typeName)
  if not typeName then return nil end
  return UNITS.COST[typeName]
end

----------------------------------------------------------------------
-- Catalogs (what GROUND/NAVAL/TRANSPORT will pick from by role)
----------------------------------------------------------------------
UNITS.GROUND = {
  BLUE = {
    TANK      = { "M-60", "AAV7", "M-113" },
    ARTILLERY = { "L118_Unit", "M-109" },
    AAA_TRUCK = { "M 818" },  -- used as staging truck for AAA evolution if desired
    AAA       = { "Vulcan", "M48 Chaparral", "Soldier stinger", "Stinger comm" },
    VEHICLE   = { "M-113", "AAV7", "M 818" },
  },
  RED = {
    TANK      = { "T-55", "PT-76", "BMP-1", "BMP-2", "BMD-1" },
    ARTILLERY = { "SAU Akatsia", "M2A1_105" },
    AAA_TRUCK = { "Ural-375 ZU-23" },
    AAA       = { "ZSU-23-4 Shilka", "ZSU_57_2", "SA-18 Igla manpad", "ZU-23 Emplacement" },
    VEHICLE   = { "MTLB", "BRDM-2", "Ural-4320T" },
  }
}

UNITS.NAVAL = {
  BLUE = {
    PATROL = { "PERRY" },
    STRIKE = { "PERRY", "USS_Samuel_Chase" },
    SHORE  = { "PERRY", "USS_Samuel_Chase" },
  },
  RED = {
    PATROL = { "REZKY" },
    STRIKE = { "REZKY", "BDK-775" },
    SHORE  = { "REZKY", "BDK-775" },
  }
}

UNITS.TRANSPORT = {
  BLUE = {
    TRUCK = { "M 818" },
    HELO  = { "CH-47Fbl1", "UH-1H" },
  },
  RED  = {
    TRUCK = { "Ural-4320T" },
    HELO  = { "Mi-8MT", "Mi-24P" },
  }
}

-- Optional: AIR fallback catalogs (if CONFIG.AIR.TYPE_BY_ROLE is absent)
UNITS.AIR = {
  BLUE = {
    CAP="F-4E-45MC", CAS="A-10A", STRIKE="F-111F", BOMB="B-52H", RECON="C-130", AWACS="E-3A", TANKER="KC-135", TRANSPORT="CH-47Fbl1"
  },
  RED  = {
    CAP="MiG-23MLD", CAS="Su-25T", STRIKE="Su-24M", BOMB="Tu-22M3", RECON="An-30M", AWACS="A-50", TANKER="IL-78M", TRANSPORT="Mi-8MT"
  }
}

----------------------------------------------------------------------
-- Utility: pick a type from a catalog
----------------------------------------------------------------------
function UNITS.listFor(sideStr, domain, role)
  sideStr = (sideStr=="RED") and "RED" or "BLUE"
  domain = tostring(domain or ""):upper()   -- "GROUND","NAVAL","TRANSPORT","AIR"
  role   = tostring(role   or ""):upper()

  local domTbl = UNITS[domain]
  if not domTbl then return nil end

  local sideTbl = domTbl[sideStr]
  if not sideTbl then return nil end

  if type(sideTbl)=="table" and sideTbl[role] then
    local v = sideTbl[role]
    if type(v)=="table" then return v elseif type(v)=="string" then return { v } end
  end
  return nil
end

function UNITS.pick(sideStr, domain, role)
  local lst = UNITS.listFor(sideStr, domain, role)
  return pick(lst)
end

info("UNITS.lua loaded (catalogs + costs ready)")
