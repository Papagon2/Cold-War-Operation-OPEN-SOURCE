-- RESTRICT.lua — Keep players on era/side-correct airframes
-- Drop-in, no dependencies except CONFIG (optional).
-- Load order: after CONFIG.lua, before OPERATIONINIT.lua.

RESTRICT = RESTRICT or {}

-- 1) Allowed types per side (use exact DCS type names).
--    Start with a core list; extend whenever you add more slots.
RESTRICT.BLUE_ALLOWED = {
  -- Fighters/strike
  ["F-4E-45MC"]=true, 
  ["F-5E-3"]=true, 
  ["F-15C"]=true, 
  ["FA-18C_hornet"]=true,
  ["F-14A-135-GR"]=true, 
  ["F-14B"]=true, 
  ["A-10A"]=true, 
  ["AJS37"]=true,
  ["AV8BNA"]=true, 
  ["M-2000C"]=true, 
  ["Mirage 2000-5"]=true, 
  ["MB-339A"]=true,
  ["F-86F Sabre"]=true, 
  ["F4U-1D"]=true,
  -- Helos / support (edit to taste)
  ["UH-1H"]=true, 
  ["CH-47F"]=true, 
  ["CH-47Fbl1"]=true,
  -- Support
  ["E-3A"]=true, 
  ["KC-135"]=true, 
  ["KC-135MPRS"]=true, 
  ["C-130"]=true,
  -- AAA
  ["FPS-117 ECS"]            = true,
  ["FPS-117"]                = true,
  ["FPS-117 Dome"]           = true,
  ["Soldier stinger"]        = true,
  ["Stinger comm"]           = true,
  ["Hawk ln"]                = true,
  ["Hawk pcp"]               = true,
  ["Hawk sr"]                = true,
  ["Hawk tr"]                = true,
  ["Hawk cwar"]              = true,
  ["Patriot cp"]             = true,
  ["Roland ADS"]             =  true,
  ["Roland Radar"]           =  true,
  ["Vulcan"]                 =  true,
  ["M48 Chaparral"]          =  true,
  -- Armor
  ["AAV7"]              = true,
  ["M-113"]             = true,
  ["M-60"]            = true,
  -- Artillery
  ["L118_Unit"]             = true,
  ["M-109"]             = true,
  -- Infantry
  ["Soldier M4"]        = true,
  ["Soldier M249"]      = true,
  -- Truck
  ["M 818"] = true,
}

RESTRICT.RED_ALLOWED = {
  -- Fighters/strike
  ["MiG-19P"]=true, 
  ["MiG-21Bis"]=true, 
  ["MiG-23MLA"]=true, 
  ["MiG-23MLD"]=true,
  ["MiG-29A"]=true, 
  ["MiG-29G"]=true, 
  ["MiG-31"]=true, 
  ["Su-27"]=true, 
  ["Su-25T"]=true,
  ["L-39C"]=true,
  -- Helos / support
  ["Mi-8MT"]=true, 
  ["Mi-24P"]=true,
  -- Support
  ["A-50"]=true, 
  ["IL-78M"]=true, 
  ["IL-76MD"]=true, 
  ["An-30M"]=true, 
  ["Tu-22M3"]=true,
  -- AAA
  ["SON_9"]                    = true,
  ["KS-19"]                    = true,
  ["S-60_Type59_Artillery"]    = true,
  ["ZU-23 Emplacement Closed"] = true,
  ["ZU-23 Emplacement"]        = true,
  ["Ural-375 ZU-23"]           = true,
  ["generator_5i57"]           = true,
  ["SA-18 Igla manpad"]        = true,
  ["SA-18 Igla comm"]          = true,
  ["Dog Ear radar"]            = true,
  ["S-300PS 64H6E sr"]         = true,
  ["S-300PS 54K6 cp"]          = true,
  ["S-300PS 40B6MD sr"]        = true,
  ["S-300PS 40B6M tr"]         = true,
  ["S-300PS 5H63C 30H6_tr"]    = true,
  ["S-300PS 5P85C ln"]         = true,
  ["S-300PS 5P85D ln"]         = true,
  ["S-300PS 40B6MD sr_19J6"]   = true,
  ["SNR_75V"]                  = true,
  ["S_75M_Volhov"]             = true,
  ["p-19 s-125 sr"]            = true,
  ["5p73 s-125 ln"]            = true,
  ["snr s-125 tr"]             = true,
  ["S-200_Launcher"]           = true,
  ["RPC_5N62V"]                = true,
  ["RLS_19J6"]                 = true,
  ["Kub 2P25 ln"]              = true,
  ["Kub 1S91 str"]             = true,
  ["Osa 9A33 ln"]              = true,
  ["Strela-1 9P31"]            = true,
  ["ZSU-23-4 Shilka"]          = true,
  ["ZSU_57_2"]                 = true,
  -- Armor
  ["BTR-D"]       = true,
  ["MTLB"]        = true,
  ["BMD-1"]       = true,
  ["BMP-1"]       = true,
  ["BMP-2"]       = true,
  ["PT-76"]       = true,
  ["T-55"]        = true,
  ["BRDM-2"]      = true,
  -- Artillery
  ["M2A1_105"]    = true,
  ["Grad_URAL"]   = true,
  ["SAU 2-C9"]    = true,
  ["SAU Akatsia"] = true,
  -- Infantry
  ["Paratrooper AKS-74"]          = true,
  ["Paratrooper RPG-16"]          = true,
  -- Truck
  ["ATMZ-5"]            = true,
  ["Ural-4320T"]        = true,
}

-- Optional: override/extend via CONFIG.RESTRICT in CONFIG.lua
if CONFIG and CONFIG.RESTRICT then
  for k,v in pairs(CONFIG.RESTRICT.BLUE_ALLOWED or {}) do RESTRICT.BLUE_ALLOWED[k]=true end
  for k,v in pairs(CONFIG.RESTRICT.RED_ALLOWED  or {}) do RESTRICT.RED_ALLOWED[k]=true  end
end

-- Behavior when someone violates the rule:
RESTRICT.ACTION = "destroy"   -- "destroy" | "warn_only"
RESTRICT.WARN_TEXT = "This airframe is not available to your coalition. Returning to spectators in 3s..."
RESTRICT.DELAY_S   = 3

local function sideAllowed(side, typename)
  if side == coalition.side.BLUE then return RESTRICT.BLUE_ALLOWED[typename] or false end
  if side == coalition.side.RED  then return RESTRICT.RED_ALLOWED[typename]  or false end
  return false
end

RESTRICT._eh = {}
function RESTRICT._eh:onEvent(e)
  if not e then return end
  -- Fires whenever a human enters a slot (works in SP/MP)
  if e.id == world.event.S_EVENT_PLAYER_ENTER_UNIT then
    local u = e.initiator; if not (u and u.isExist and u:isExist()) then return end
    local side = u:getCoalition()
    local t    = u:getTypeName()
    if sideAllowed(side, t) then return end

    local g = u:getGroup()
    if g and g.getID then trigger.action.outTextForGroup(g:getID(), RESTRICT.WARN_TEXT, 10) end

    if RESTRICT.ACTION == "destroy" then
      timer.scheduleFunction(function()
        if u and u.isExist and u:isExist() then
          -- small pop to clear the slot cleanly without wreckage spam
          local p=u:getPoint()
          trigger.action.explosion({x=p.x, y=p.z}, 1)
          pcall(function() u:destroy() end)
        end
      end, {}, timer.getTime() + (RESTRICT.DELAY_S or 2))
    end
  end
end
pcall(function() trigger.action.outText("RESTRICT.lua LOADED...).", 5) end)
world.addEventHandler(RESTRICT._eh)
