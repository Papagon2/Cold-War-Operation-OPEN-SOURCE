-- OPERATIONINIT.lua — Cold-War Breach master init & event wiring
-- Responsibilities:
--  • Initialize all modules in a safe order (if present)
--  • Bridge DCS base-capture events into TERRAIN/STATE/MARK/AIR
--  • Optional: bootstrap starting AI wings from CONFIG.BOOTSTRAP
--  • Optional: tiny F10 “Admin” menu for quick toggles

OPERATIONINIT = OPERATIONINIT or {}

local function now() return timer.getTime() end
local function say(t, d) trigger.action.outText("[OP INIT] "..tostring(t), d or 5) end
local function info(t) if env and env.info then env.info("[OP INIT] "..tostring(t)) end end
local function fmt(...) return string.format(...) end

-- Safe call helper
local function try(tag, fn, ...)
  if type(fn) ~= "function" then return false, "nofn" end
  local ok, err = pcall(fn, ...)
  if not ok then env.info("[OP INIT] "..tag.." failed: "..tostring(err)) end
  return ok, err
end

-- Normalize coalition → "BLUE"/"RED"/"NEUTRAL"
local function toSideStr(cside)
  if cside == coalition.side.BLUE or cside == 2 then return "BLUE" end
  if cside == coalition.side.RED  or cside == 1 then return "RED"  end
  return "NEUTRAL"
end

---------------------------------------------------------------------
-- 1) Event bridge: airbase captured → TERRAIN.setOwner + updates
---------------------------------------------------------------------
OPERATIONINIT._eh = OPERATIONINIT._eh or {}
function OPERATIONINIT._eh:onEvent(e)
  if not e or not e.id then return end

  if e.id == world.event.S_EVENT_BASE_CAPTURED and e.place and TERRAIN and TERRAIN.setOwner then
    local afName = (e.place.getName and e.place:getName()) or tostring(e.place)
    if not afName then return end

    -- Old owner (before flip)
    local oldSideStr = "NEUTRAL"
    if TERRAIN.getOwner then
      local old = TERRAIN.getOwner(afName)
      oldSideStr = toSideStr(old)
    end

    -- New owner from event
    local newCoal = (e.initiator and e.initiator.getCoalition and e.initiator:getCoalition()) or e.coalition
    local newOwnerCoal = (newCoal == coalition.side.RED) and coalition.side.RED or coalition.side.BLUE
    local newSideStr = toSideStr(newOwnerCoal)

    -- Commit ownership change into TERRAIN
    TERRAIN.setOwner(afName, newOwnerCoal)

    -- Notify STATE (economy), MARK (overlay), AIR (support re-task)
    if STATE and STATE.onCapture then pcall(STATE.onCapture, afName, newSideStr, oldSideStr) end
    if MARK  and (MARK.onCapture or MARK.updateAirfield) then
      if MARK.onCapture then pcall(MARK.onCapture, afName) else pcall(MARK.updateAirfield, afName) end
    end
    if AIR and AIR.support and AIR.support.onCapture then
      pcall(AIR.support.onCapture, afName, newSideStr, oldSideStr)
    end
  end
end

---------------------------------------------------------------------
-- 2) Optional Admin menu (for server/GMs)
---------------------------------------------------------------------
local function buildAdminMenu()
  if not CONFIG or not CONFIG.ADMIN_MENU then return end

local function flipDebug(tag, mod)
  if not mod then return end
  if mod.cfg and type(mod.cfg)=="table" and mod.cfg.debug ~= nil then
    mod.cfg.debug = not mod.cfg.debug; say(tag.." debug = "..tostring(mod.cfg.debug), 6)
  elseif mod.debug ~= nil then
    mod.debug = not mod.debug; say(tag.." debug = "..tostring(mod.debug), 6)
  else
    say(tag.." has no debug flag", 6)
  end
end

local root = missionCommands.addSubMenu("Admin")
missionCommands.addCommand("Toggle AIR debug",       root, function() flipDebug("AIR",       AIR) end)
missionCommands.addCommand("Toggle TRANSPORT debug", root, function() flipDebug("TRANSPORT", TRANSPORT) end)
missionCommands.addCommand("Toggle FERRY debug",     root, function() flipDebug("FERRY",     FERRY) end)
missionCommands.addCommand("Toggle NAVAL debug",     root, function() flipDebug("NAVAL",     NAVAL) end)
missionCommands.addCommand("Toggle STATE debug",     root, function() flipDebug("STATE",     STATE) end)

  -- Handy CAP spawns from the currently active “home” AF
  missionCommands.addCommand("Spawn BLUE CAP (home)", root, function()
    if AIR and TERRAIN and TERRAIN.getActiveHomeFor then
      local af = TERRAIN.getActiveHomeFor("BLUE"); if af then AIR.requestWing{ side="BLUE", role="CAP", from=af } end
    end
  end)
  missionCommands.addCommand("Spawn RED CAP (home)", root, function()
    if AIR and TERRAIN and TERRAIN.getActiveHomeFor then
      local af = TERRAIN.getActiveHomeFor("RED"); if af then AIR.requestWing{ side="RED", role="CAP", from=af } end
    end
  end)
end

---------------------------------------------------------------------
-- 3) Optional bootstraps (via CONFIG.BOOTSTRAP)
---------------------------------------------------------------------
local function doBootstrap()
  if not CONFIG or not CONFIG.BOOTSTRAP then return end
  if CONFIG.BOOTSTRAP.AIR and AIR and AIR.bootstrap then
    AIR.bootstrap(CONFIG.BOOTSTRAP.AIR)
  end
end

---------------------------------------------------------------------
-- 4) Init: call all module init() in a safe order
---------------------------------------------------------------------
function OPERATIONINIT.start()
  if OPERATIONINIT._started then return end
  OPERATIONINIT._started = true

  -- Register event handler first so we never miss a capture
  world.addEventHandler(OPERATIONINIT._eh)

  -- TERRAIN presence (ownership tables, zones, etc.)
  if TERRAIN and TERRAIN.AIRFIELDS then
    local cnt=0; for _ in pairs(TERRAIN.AIRFIELDS) do cnt=cnt+1 end
    info("TERRAIN present with "..tostring(cnt).." airfields.")
  end

-- Economy first (seeding + income tick)
if STATE and STATE.init then try("STATE.init", STATE.init, CONFIG and CONFIG.STATE) end

-- Map markers
local markInterval = (CONFIG and CONFIG.MARK and CONFIG.MARK.REFRESH_SEC) or 30
if MARK and MARK.init then try("MARK.init", MARK.init, { interval = markInterval, cfg = CONFIG and CONFIG.MARK }) end

-- Core ground/logistics layers
if GROUND    and GROUND.init    then try("GROUND.init",    GROUND.init,    CONFIG and CONFIG.GROUND)    end
if FERRY     and FERRY.init     then try("FERRY.init",     FERRY.init,     { cfg = CONFIG and CONFIG.GROUND }) end
if TRANSPORT and TRANSPORT.init then try("TRANSPORT.init", TRANSPORT.init, CONFIG and CONFIG.TRANSPORT) end

-- Air layer
if AIR and AIR.init then try("AIR.init", AIR.init, CONFIG and CONFIG.AIR) end

-- Side missions
if SIDEMISSIONS and SIDEMISSIONS.init then try("SIDEMISSIONS.init", SIDEMISSIONS.init, CONFIG and CONFIG.SIDEMISSIONS) end

-- Naval
if NAVAL and NAVAL.init then try("NAVAL.init", NAVAL.init, CONFIG and CONFIG.NAVAL) end

-- Pickup
if PICKUP and PICKUP.init then try("PICKUP.init", PICKUP.init, CONFIG and CONFIG.PICKUP) end

-- Player restrictions
if RESTRICT and RESTRICT.init then try("RESTRICT.init", RESTRICT.init, CONFIG and CONFIG.RESTRICT) end

  -- Admin menu & initial bootstrap
  buildAdminMenu()
  doBootstrap()

  say("Operation initialized.", 8)
  info("Operation Cold-War Breach initialized.")
end

---------------------------------------------------------------------
-- 5) Auto-start shortly after mission start
---------------------------------------------------------------------
timer.scheduleFunction(function()
  OPERATIONINIT.start()
  return nil
end, {}, now() + 3)

return OPERATIONINIT
