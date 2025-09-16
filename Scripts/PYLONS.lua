-- PYLONS.lua — Catalog + fast index + (best-effort) runtime applier
-- Feeds LOADOUT.lua / AIR.lua
--
-- Keep the big PYLONS = { {unitType="...", payloads={ {name="...", pylons={...}}, ...}}, ... } table.
-- This file will:
--   1) Validate & normalize that catalog
--   2) Build PYLON_PRESETS[unitType][presetName] for O(1) lookups
--   3) Expose PYLONS.applyForGroup(groupName, presetName) used by LOADOUT.applyByName/Role

---------------------------------------------------------------------
-- 1) YOUR CATALOG (keep everything you already have between the lines)
---------------------------------------------------------------------
-- BEGIN CATALOG
PYLONS = PYLONS or {
  {
    unitType = "F-4E-45MC",
    payloads = {
      {
        name = "A2A LONG RANGE",
        pylons = {
          [1] = { num = 8,  CLSID = "{HB_F4E_AIM-7E}" },
          [2] = { num = 9,  CLSID = "{HB_F4E_AIM-7E}" },
          [3] = { num = 7,  CLSID = "{F4_SARGENT_TANK_600_GAL}" },
          [4] = { num = 6,  CLSID = "{HB_F4E_AIM-7E}" },
          [5] = { num = 5,  CLSID = "{HB_F4E_AIM-7E}" },
          [6] = { num = 13, CLSID = "{F4_SARGENT_TANK_370_GAL_R}" },
          [7] = { num = 1,  CLSID = "{F4_SARGENT_TANK_370_GAL}" },
          [8] = { num = 14, CLSID = "{HB_ALE_40_30_60}" },
          [9] = { num = 11, CLSID = "{HB_F4E_ROCKEYE_3x}"},
          [10] = { num = 3, CLSID = "{HB_F4E_ROCKEYE_3x}"},
        }
      },
      {
        name = "FullLoad",
        pylons = {
          [1]  = { num = 14, CLSID = "{HB_ALE_40_30_60}" },
          [2]  = { num = 13, CLSID = "{HB_F4E_MK-82_6x}" },
          [3]  = { num = 12, CLSID = "{AIM-9J}" },
          [4]  = { num = 10, CLSID = "{AIM-9J}" },
          [5]  = { num = 9,  CLSID = "{HB_F4E_AIM-7E}" },
          [6]  = { num = 8,  CLSID = "{HB_F4E_AIM-7E}" },
          [7]  = { num = 7,  CLSID = "{F4_SARGENT_TANK_600_GAL}" },
          [8]  = { num = 6,  CLSID = "{HB_F4E_AIM-7E}" },
          [9]  = { num = 5,  CLSID = "{HB_F4E_AIM-7E}" },
          [10] = { num = 4,  CLSID = "{AIM-9J}" },
          [11] = { num = 2,  CLSID = "{AIM-9J}" },
          [12] = { num = 1,  CLSID = "{HB_F4E_MK-82_6x}" },
        }
      },
      {
        name = "Air2AirFull",
        pylons = {
          [1]  = { num = 14, CLSID = "{HB_ALE_40_30_60}" },
          [2]  = { num = 13, CLSID = "{F4_SARGENT_TANK_370_GAL_R}" },
          [3]  = { num = 12, CLSID = "{AIM-9J}" },
          [4]  = { num = 10, CLSID = "{AIM-9J}" },
          [5]  = { num = 9,  CLSID = "{HB_F4E_AIM-7E}" },
          [6]  = { num = 8,  CLSID = "{HB_F4E_AIM-7E}" },
          [7]  = { num = 7,  CLSID = "{F4_SARGENT_TANK_600_GAL}" },
          [8]  = { num = 6,  CLSID = "{HB_F4E_AIM-7E}" },
          [9]  = { num = 5,  CLSID = "{HB_F4E_AIM-7E}" },
          [10] = { num = 4,  CLSID = "{AIM-9J}" },
          [11] = { num = 2,  CLSID = "{AIM-9J}" },
          [12] = { num = 1,  CLSID = "{F4_SARGENT_TANK_370_GAL}" }, -- left 370 gal
        }
      },
      {
        name = "BombFull",
        pylons = {
          [1] = { num = 14, CLSID = "{HB_ALE_40_30_60}" },
          [2] = { num = 13, CLSID = "{HB_F4E_MK-82_6x}" },
          [3] = { num = 11, CLSID = "{HB_F4E_MK-82_3x}" },
          [4] = { num = 9,  CLSID = "{HB_F4E_AIM-7E}" },
          [5] = { num = 8,  CLSID = "{HB_F4E_AIM-7E}" },
          [6] = { num = 7,  CLSID = "{F4_SARGENT_TANK_600_GAL}" },
          [7] = { num = 6,  CLSID = "{HB_F4E_AIM-7E}" },
          [8] = { num = 5,  CLSID = "{HB_F4E_AIM-7E}" },
          [9] = { num = 3,  CLSID = "{HB_F4E_MK-82_3x}" },
          [10] = { num = 1,  CLSID = "{HB_F4E_MK-82_6x}" },
        }
      },
    }
  },

  {
    unitType = "F-5E-3",  -- <- exact DCS type string
    payloads = {
      {
        name = "AG",
        pylons = {
          [1] = { num = 7, CLSID = "{AIM-9J}" },
          [2] = { num = 1, CLSID = "{AIM-9J}" },
          [3] = { num = 6, CLSID = "{BCE4E030-38E9-423E-98ED-24BE3DA87C32}" }, -- Mk-82 LD
          [4] = { num = 5, CLSID = "{PTB-150GAL}" },
          [5] = { num = 3, CLSID = "{PTB-150GAL}" },
          [6] = { num = 4, CLSID = "{7A44FF09-527C-4B7E-B42B-3F111CFE50FB}" }, -- Mk-83 LD
          [7] = { num = 2, CLSID = "{BCE4E030-38E9-423E-98ED-24BE3DA87C32}" }, -- Mk-82 LD
        }
      },
      {
        name = "AA",
        pylons = {
          [1] = { num = 7, CLSID = "{AIM-9J}" },
          [2] = { num = 1, CLSID = "{AIM-9J}" },
          [3] = { num = 4, CLSID = "{7A44FF09-527C-4B7E-B42B-3F111CFE50FB}" }, -- Mk-83 LD
        }
      },
    }
  },

  {
    unitType = "A-10A",  -- <- exact DCS type string
    payloads = {
      {
        name = "BombFull",
        pylons = {
          [1]  = { num = 11, CLSID = "LAU-105_2*AIM-9L" },
          [2]  = { num = 10, CLSID = "{BCE4E030-38E9-423E-98ED-24BE3DA87C32}" },
          [3]  = { num = 9,  CLSID = "{60CC734F-0AFA-4E2E-82B8-93B941AB11CF}" },
          [4]  = { num = 8,  CLSID = "{60CC734F-0AFA-4E2E-82B8-93B941AB11CF}" },
          [5]  = { num = 7,  CLSID = "{BCE4E030-38E9-423E-98ED-24BE3DA87C32}" },
          [6]  = { num = 5,  CLSID = "{BCE4E030-38E9-423E-98ED-24BE3DA87C32}" },
          [7]  = { num = 4,  CLSID = "{60CC734F-0AFA-4E2E-82B8-93B941AB11CF}" },
          [8]  = { num = 3,  CLSID = "{60CC734F-0AFA-4E2E-82B8-93B941AB11CF}" },
          [9]  = { num = 2,  CLSID = "{BCE4E030-38E9-423E-98ED-24BE3DA87C32}" },
          [10] = { num = 1,  CLSID = "{6D21ECEA-F85B-4E8D-9D51-31DC9B8AA4EF}" }, -- Mk-82 LD
        }
      },
      {
        name = "AGRockets",
        pylons = {
          [1] = { num = 11, CLSID = "LAU-105_2*AIM-9L" },
          [2] = { num = 10, CLSID = "{319293F2-392C-4617-8315-7C88C22AF7C4}" },
          [3] = { num = 9,  CLSID = "{DAC53A2F-79CA-42FF-A77A-F5649B601308}" },
          [4] = { num = 8,  CLSID = "{319293F2-392C-4617-8315-7C88C22AF7C4}" },
          [5] = { num = 6,  CLSID = "Fuel_Tank_FT600" },
          [6] = { num = 4,  CLSID = "{319293F2-392C-4617-8315-7C88C22AF7C4}" },
          [7] = { num = 3,  CLSID = "{DAC53A2F-79CA-42FF-A77A-F5649B601308}" },
          [8] = { num = 2,  CLSID = "{319293F2-392C-4617-8315-7C88C22AF7C4}" },
          [9] = { num = 1,  CLSID = "{6D21ECEA-F85B-4E8D-9D51-31DC9B8AA4EF}" },
        }
      },
    }
  },

  {
    unitType = "AJS37",  -- <- exact DCS type string
    payloads = {
      {
        name = "AGRockets",
        pylons = {
          [1] = { num = 7, CLSID = "{Robot24}" },
          [2] = { num = 6, CLSID = "{ARAKM70BAP}" },
          [3] = { num = 5, CLSID = "{ARAKM70BAP}" },
          [4] = { num = 4, CLSID = "{VIGGEN_X-TANK}" },
          [5] = { num = 3, CLSID = "{ARAKM70BAP}" },
          [6] = { num = 2, CLSID = "{ARAKM70BAP}" },
          [7] = { num = 1, CLSID = "{Robot24}" },
        }
      },
      {
        name = "AntiShip",
        pylons = {
          [1] = { num = 7, CLSID = "{Robot24}" },
          [2] = { num = 6, CLSID = "{Rb04_HB}" },
          [3] = { num = 5, CLSID = "{Robot05}" },
          [4] = { num = 4, CLSID = "{VIGGEN_X-TANK}" },
          [5] = { num = 3, CLSID = "{Robot05}" },
          [6] = { num = 2, CLSID = "{Rb04_HB}" },
          [7] = { num = 1, CLSID = "{Robot24}" },
        }
      },
      {
        name = "BombFull",
        pylons = {
          [1] = { num = 7, CLSID = "{Robot24}" },
          [2] = { num = 6, CLSID = "{M71BOMBD}" },
          [3] = { num = 5, CLSID = "{M71BOMBD}" },
          [4] = { num = 4, CLSID = "{VIGGEN_X-TANK}" },
          [5] = { num = 3, CLSID = "{M71BOMBD}" },
          [6] = { num = 2, CLSID = "{M71BOMBD}" },
          [7] = { num = 1, CLSID = "{Robot24}" },
        }
      },
      {
        name = "AGMissile",
        pylons = {
          [1] = { num = 7, CLSID = "{Robot24}" },
          [2] = { num = 6, CLSID = "{RB75}" },
          [3] = { num = 5, CLSID = "{RB75}" },
          [4] = { num = 4, CLSID = "{VIGGEN_X-TANK}" },
          [5] = { num = 3, CLSID = "{RB75}" },
          [6] = { num = 2, CLSID = "{RB75}" },
          [7] = { num = 1, CLSID = "{Robot24}" },
        }
      },
    }
  },

  {
    unitType = "AV88NA",  -- <- exact DCS type string
    payloads = {
      {
        name = "Air2AirFull",
        pylons = {
          [1] = { num = 8, CLSID = "{AIM-9L}" },
          [2] = { num = 7, CLSID = "{AIM-9L-ON-ADAPTER}" },
          [3] = { num = 6, CLSID = "{AV8BNA_AERO1D}" },
          [4] = { num = 5, CLSID = "{ALQ_164_RF_Jammer}" },
          [5] = { num = 4, CLSID = "{GAU_12_Equalizer}" },
          [6] = { num = 3, CLSID = "{AV8BNA_AERO1D}" },
          [7] = { num = 2, CLSID = "{AIM-9L-ON-ADAPTER}" },
          [8] = { num = 1, CLSID = "{AIM-9L}" },
        }
      },
      {
        name = "AGRockets",
        pylons = {
          [1] = { num = 8, CLSID = "{AIM-9L}" },
          [2] = { num = 7, CLSID = "{LAU3_HE5}" },
          [3] = { num = 6, CLSID = "{LAU3_HE5}" },
          [4] = { num = 5, CLSID = "{ALQ_164_RF_Jammer}" },
          [5] = { num = 4, CLSID = "{GAU_12_Equalizer}" },
          [6] = { num = 3, CLSID = "{LAU3_HE5}" },
          [7] = { num = 2, CLSID = "{LAU3_HE5}" },
          [8] = { num = 1, CLSID = "{AIM-9L}" },
        }
      },
      {
        name = "BombFull",
        pylons = {
          [1] = { num = 8, CLSID = "{BCE4E030-38E9-423E-98ED-24BE3DA87C32}" },
          [2] = { num = 7, CLSID = "{BRU-42_3*Mk-82LD}" },
          [3] = { num = 6, CLSID = "{BRU-42_2*Mk-82_RIGHT}" },
          [4] = { num = 5, CLSID = "{ALQ_164_RF_Jammer}" },
          [5] = { num = 4, CLSID = "{GAU_12_Equalizer}" },
          [6] = { num = 3, CLSID = "{BRU-42_2*Mk-82_LEFT}" },
          [7] = { num = 2, CLSID = "{BRU-42_3*Mk-82LD}" },
          [8] = { num = 1, CLSID = "{BCE4E030-38E9-423E-98ED-24BE3DA87C32}" },
        }
      },
      {
        name = "AGMissile",
        pylons = {
          [1] = { num = 8, CLSID = "{AIM-9L}" },
          [2] = { num = 7, CLSID = "{F16A4DE0-116C-4A71-97F0-2CF85B0313EC}" },
          [3] = { num = 6, CLSID = "{F16A4DE0-116C-4A71-97F0-2CF85B0313EC}" },
          [4] = { num = 5, CLSID = "{ALQ_164_RF_Jammer}" },
          [5] = { num = 4, CLSID = "{GAU_12_Equalizer}" },
          [6] = { num = 3, CLSID = "{F16A4DE0-116C-4A71-97F0-2CF85B0313EC}" },
          [7] = { num = 2, CLSID = "{F16A4DE0-116C-4A71-97F0-2CF85B0313EC}" },
          [8] = { num = 1, CLSID = "{AIM-9L}" },
        }
      },
    }
  },

  {
    unitType = "F-14B",  -- <- exact DCS type string
    payloads = {
      {
        name = "Air2AirFull",
        pylons = {
          [1]  = { num = 10, CLSID = "{LAU-138 wtip - AIM-9L}" },
          [2]  = { num = 9,  CLSID = "{SHOULDER AIM-7F}" },
          [3]  = { num = 8,  CLSID = "{F14-300gal}" },
          [4]  = { num = 7,  CLSID = "{AIM_54C_Mk60}" },
          [5]  = { num = 6,  CLSID = "{AIM_54C_Mk60}" },
          [6]  = { num = 5,  CLSID = "{AIM_54C_Mk60}" },
          [7]  = { num = 4,  CLSID = "{AIM_54C_Mk60}" },
          [8]  = { num = 3,  CLSID = "{F14-300gal}" },
          [9]  = { num = 2,  CLSID = "{SHOULDER AIM-7F}" },
          [10] = { num = 1,  CLSID = "{LAU-138 wtip - AIM-9L}" },
        }
      },
      {
        name = "AGRockets",
        pylons = {
          [1]  = { num = 10, CLSID = "{LAU-105_2*AIM-9L}" },
          [2]  = { num = 9,  CLSID = "{PHXBRU3242_2*LAU10 RS}" },
          [3]  = { num = 8,  CLSID = "{F14-300gal}" },
          [4]  = { num = 7,  CLSID = "{BRU3242_LAU10}" },
          [5]  = { num = 6,  CLSID = "{Fuel_Tank_FT600}" },
          [6]  = { num = 5,  CLSID = "{<CLEAN>}" },
          [7]  = { num = 4,  CLSID = "{BRU3242_2*LAU10 R}" },
          [8]  = { num = 3,  CLSID = "{F14-300gal}" },
          [9]  = { num = 2,  CLSID = "{PHXBRU3242_2*LAU10 LS}" },
          [10] = { num = 1,  CLSID = "{LAU-138 wtip - AIM-9L}" },
        }
      },
      {
        name = "BombFull",
        pylons = {
          [1]  = { num = 10, CLSID = "{LAU-105_2*AIM-9L}" },
          [2]  = { num = 9,  CLSID = "{PHXBRU3242_2*MK82 RS}" },
          [3]  = { num = 8,  CLSID = "{F14-300gal}" },
          [4]  = { num = 7,  CLSID = "{MAK79_MK82 4}" },
          [5]  = { num = 6,  CLSID = "{MAK79_MK82 3R}" },
          [6]  = { num = 5,  CLSID = "{MAK79_MK82 3L}" },
          [7]  = { num = 4,  CLSID = "{MAK79_MK82 4}" },
          [8]  = { num = 3,  CLSID = "{F14-300gal}" },
          [9]  = { num = 2,  CLSID = "{PHXBRU3242_2*MK82 LS}" },
          [10] = { num = 1, CLSID = "{LAU-138 wtip - AIM-9L}" },
        }
      },
    }
  },

  {
    unitType = "F-15C",  -- <- exact DCS type string
    payloads = {
      {
        name = "Air2AirFull",
        pylons = {
          [1]  = { num = 11, CLSID = "{AIM-9L}" },
          [2]  = { num = 10, CLSID = "{E1F29B21-F291-4589-9FD8-3272EEC69506}" },
          [3]  = { num = 9,  CLSID = "{AIM-9L}" },
          [4]  = { num = 8,  CLSID = "{AIM-7E}" },
          [5]  = { num = 7,  CLSID = "{AIM-7E}" },
          [6]  = { num = 6,  CLSID = "{E1F29B21-F291-4589-9FD8-3272EEC69506}" },
          [7]  = { num = 5,  CLSID = "{AIM-7E}" },
          [8]  = { num = 4,  CLSID = "{AIM-7E}" },
          [9]  = { num = 3,  CLSID = "{AIM-9L}" },
          [10] = { num = 2,  CLSID = "{E1F29B21-F291-4589-9FD8-3272EEC69506}" },
          [11] = { num = 1,  CLSID = "{AIM-9L}" },
        }
      },
    }
  },

  {
    unitType = "F-16A",  -- <- exact DCS type string
    payloads = {
      {
        name = "Air2AirFull",
        pylons = {
          [1] = { num = 10, CLSID = "{AIM-9L}" },
          [2] = { num = 9,  CLSID = "{AIM-9L}" },
          [3] = { num = 8,  CLSID = "{8D399DDA-FF81-4F14-904D-099B34FE7918}" },
          [4] = { num = 7,  CLSID = "{F376DBEE-4CAE-41BA-ADD9-B2910AC95DEC}" },
          [5] = { num = 6,  CLSID = "{6D21ECEA-F85B-4E8D-9D51-31DC9B8AA4EF}" },
          [6] = { num = 4,  CLSID = "{F376DBEE-4CAE-41BA-ADD9-B2910AC95DEC}" },
          [7] = { num = 3,  CLSID = "{8D399DDA-FF81-4F14-904D-099B34FE7918}" },
          [8] = { num = 2,  CLSID = "{AIM-9L}" },
          [9] = { num = 1,  CLSID = "{AIM-9L}" },
        }
      },
      {
        name = "AGMissile",
        pylons = {
          [1] = { num = 10, CLSID = "{AIM-9L}" },
          [2] = { num = 9,  CLSID = "{AIM-9L}" },
          [3] = { num = 8,  CLSID = "{7B8DCEB4-820B-4015-9B48-1028A4195692}" },
          [4] = { num = 7,  CLSID = "{F376DBEE-4CAE-41BA-ADD9-B2910AC95DEC}" },
          [5] = { num = 6,  CLSID = "{6D21ECEA-F85B-4E8D-9D51-31DC9B8AA4EF}" },
          [6] = { num = 4,  CLSID = "{F376DBEE-4CAE-41BA-ADD9-B2910AC95DEC}" },
          [7] = { num = 3,  CLSID = "{7B8DCEB4-820B-4015-9B48-1028A4195692}" },
          [8] = { num = 2,  CLSID = "{AIM-9L}" },
          [9] = { num = 1,  CLSID = "{AIM-9L}" },
        }
      },
      {
        name = "BombFull",
        pylons = {
          [1] = { num = 10, CLSID = "{AIM-9L}" },
          [2] = { num = 9,  CLSID = "{AIM-9L}" },
          [3] = { num = 8,  CLSID = "{60CC734F-0AFA-4E2E-82B8-93B941AB11CF}" },
          [4] = { num = 7,  CLSID = "{F376DBEE-4CAE-41BA-ADD9-B2910AC95DEC}" },
          [5] = { num = 6,  CLSID = "{6D21ECEA-F85B-4E8D-9D51-31DC9B8AA4EF}" },
          [6] = { num = 4,  CLSID = "{F376DBEE-4CAE-41BA-ADD9-B2910AC95DEC}" },
          [7] = { num = 3,  CLSID = "{60CC734F-0AFA-4E2E-82B8-93B941AB11CF}" },
          [8] = { num = 2,  CLSID = "{AIM-9L}" },
          [9] = { num = 1,  CLSID = "{AIM-9L}" },
        }
      },
    }
  },

  {
    unitType = "F-86F Sabre",  -- <- exact DCS type string
    payloads = {
      {
        name = "AGRockets",
        pylons = {
          [1]  = { num = 10, CLSID = "{HVARx2}" },
          [2]  = { num = 9,  CLSID = "{HVARx2}" },
          [3]  = { num = 8,  CLSID = "{HVARx2}" },
          [4]  = { num = 7,  CLSID = "{HVARx2}" },
          [5]  = { num = 6,  CLSID = "{GAR-8}" },
          [6]  = { num = 5,  CLSID = "{GAR-8}" },
          [7]  = { num = 4,  CLSID = "{HVARx2}" },
          [8]  = { num = 3,  CLSID = "{HVARx2}" },
          [9]  = { num = 2,  CLSID = "{HVARx2}" },
          [10] = { num = 1,  CLSID = "{HVARx2}" },
        }
      },
      {
        name = "BombFull",
        pylons = {
          [1] = { num = 10, CLSID = "{PTB_120_F86F35}" },
          [2] = { num = 7,  CLSID = "{00F5DAC4-0466-4122-998F-B1A298E34113}" },
          [3] = { num = 6,  CLSID = "{GAR-8}" },
          [4] = { num = 5,  CLSID = "{GAR-8}" },
          [5] = { num = 4,  CLSID = "{00F5DAC4-0466-4122-998F-B1A298E34113}" },
          [6] = { num = 1,  CLSID = "{PTB_120_F86F35}" },
        }
      },
    }
  },

  {
    unitType = "M-2000C",  -- <- exact DCS type string
    payloads = {
      {
        name = "Air2AirFull",
        pylons = {
          [1] = { num = 10, CLSID = "{EclairM_42}" },
          [2] = { num = 9,  CLSID = "{MMagicII}" },
          [3] = { num = 8,  CLSID = "{MMagicII}" },
          [4] = { num = 5,  CLSID = "{M2KC_RPL_522}" },
          [5] = { num = 4,  CLSID = "{HVARx2}" },
          [6] = { num = 3,  CLSID = "{HVARx2}" },
          [7] = { num = 2,  CLSID = "{MMagicII}" },
          [8] = { num = 1,  CLSID = "{MMagicII}" },
        }
      },
      {
        name = "BombFull",
        pylons = {
          [1]  = { num = 10, CLSID = "{EclairM_42}" },
          [2]  = { num = 9,  CLSID = "{Matra155RocketPod}" },
          [3]  = { num = 8,  CLSID = "{Matra155RocketPod}" },
          [4]  = { num = 7,  CLSID = "{BCE4E030-38E9-423E-98ED-24BE3DA87C32}" },
          [5]  = { num = 6,  CLSID = "{BCE4E030-38E9-423E-98ED-24BE3DA87C32}" },
          [6]  = { num = 5,  CLSID = "{M2KC_BAP100_12_RACK}" },
          [7]  = { num = 4,  CLSID = "{BCE4E030-38E9-423E-98ED-24BE3DA87C32}" },
          [8]  = { num = 3,  CLSID = "{BCE4E030-38E9-423E-98ED-24BE3DA87C32}" },
          [9]  = { num = 2,  CLSID = "{Matra155RocketPod}" },
          [10] = { num = 1,  CLSID = "{Matra155RocketPod}" },
        }
      },
    }
  },

  {
    unitType = "Mirage 2000-5",  -- <- exact DCS type string
    payloads = {
      {
        name = "Air2AirFull",
        pylons = {
          [1] = { num = 9, CLSID = "{FC23864E-3B80-48E3-9C03-4DA8B1D7497B}" },
          [2] = { num = 8, CLSID = "{6D778860-7BB8-4ACB-9E95-BA772C6BBC2C}" },
          [3] = { num = 7, CLSID = "{6D778860-7BB8-4ACB-9E95-BA772C6BBC2C}" },
          [4] = { num = 6, CLSID = "{6D778860-7BB8-4ACB-9E95-BA772C6BBC2C}" },
          [5] = { num = 5, CLSID = "{414DA830-B61A-4F9E-B71B-C2F6832E1D7A}" },
          [6] = { num = 4, CLSID = "{6D778860-7BB8-4ACB-9E95-BA772C6BBC2C}" },
          [7] = { num = 3, CLSID = "{6D778860-7BB8-4ACB-9E95-BA772C6BBC2C}" },
          [8] = { num = 2, CLSID = "{6D778860-7BB8-4ACB-9E95-BA772C6BBC2C}" },
          [9] = { num = 1, CLSID = "{FC23864E-3B80-48E3-9C03-4DA8B1D7497B}" },
        }
      },
    }
  },

  {
    unitType = "MB-339A",  -- <- exact DCS type string
    payloads = {
      {
        name = "AGRockets",
        pylons = {
          [1] = { num = 10, CLSID = "{FUEL-TIP-TANK-500-R}" },
          [2] = { num = 9,  CLSID = "{LR25_ARF8M3_HEI}" },
          [3] = { num = 8,  CLSID = "{LR25_ARF8M3_HEI}" },
          [4] = { num = 7,  CLSID = "{LR25_ARF8M3_HEI}" },
          [5] = { num = 4,  CLSID = "{LR25_ARF8M3_HEI}" },
          [6] = { num = 3,  CLSID = "{LR25_ARF8M3_HEI}" },
          [7] = { num = 2,  CLSID = "{LR25_ARF8M3_HEI}" },
          [8] = { num = 1,  CLSID = "{FUEL-TIP-TANK-500-L}" },
        }
      },
      {
        name = "BombFull",
        pylons = {
          [1] = { num = 10, CLSID = "{FUEL-TIP-TANK-500-R}" },
          [2] = { num = 9,  CLSID = "{BCE4E030-38E9-423E-98ED-24BE3DA87C32}" },
          [3] = { num = 8,  CLSID = "{BCE4E030-38E9-423E-98ED-24BE3DA87C32}" },
          [4] = { num = 7,  CLSID = "{BCE4E030-38E9-423E-98ED-24BE3DA87C32}" },
          [5] = { num = 4,  CLSID = "{BCE4E030-38E9-423E-98ED-24BE3DA87C32}" },
          [6] = { num = 3,  CLSID = "{BCE4E030-38E9-423E-98ED-24BE3DA87C32}" },
          [7] = { num = 2,  CLSID = "{BCE4E030-38E9-423E-98ED-24BE3DA87C32}" },
          [8] = { num = 1,  CLSID = "{FUEL-TIP-TANK-500-L}" },
        }
      },
      {
        name = "AGGun",
        pylons = {
          [1] = { num = 10, CLSID = "{FUEL-TIP-ELLITTIC-R}" },
          [2] = { num = 9,  CLSID = "{LR25_ARF8M3_HEI}" },
          [3] = { num = 7,  CLSID = "{MB339_DEFA553_R}" },
          [4] = { num = 4,  CLSID = "{MB339_DEFA553_L}" },
          [5] = { num = 2,  CLSID = "{LR25_ARF8M3_HEI}" },
          [6] = { num = 1,  CLSID = "{FUEL-TIP-ELLITTIC-L}" },
        }
      },
    }
  },

  {
    unitType = "L-39C",  -- <- exact DCS type string
    payloads = {
      {
        name = "AGRockets",
        pylons = {
          [1] = { num = 3, CLSID = "{UB-16-57UMP}" },
          [2] = { num = 1, CLSID = "{UB-16-57UMP}" },
        }
      },
      {
        name = "BombFull",
        pylons = {
          [1] = { num = 3, CLSID = "{FB3CE165-BF07-4979-887C-92B87F13276B}" },
          [2] = { num = 1, CLSID = "{FB3CE165-BF07-4979-887C-92B87F13276B}" },
        }
      },
      {
        name = "Air2AirFull",
        pylons = {
          [1] = { num = 3, CLSID = "{R-3S}" },
          [2] = { num = 1, CLSID = "{R-3S}" },
        }
      },
    }
  },

  {
    unitType = "MiG-19P",  -- <- exact DCS type string
    payloads = {
      {
        name = "Air2AirFull",
        pylons = {
          [1] = { num = 6, CLSID = "{K-13A}" },
          [2] = { num = 5, CLSID = "{PTB760_MIG19}" },
          [3] = { num = 2, CLSID = "{PTB760_MIG19}" },
          [4] = { num = 1, CLSID = "{K-13A}" },
        }
      },
      {
        name = "AGRockets",
        pylons = {
          [1] = { num = 6, CLSID = "{K-13A}" },
          [2] = { num = 5, CLSID = "{ORO57K_S5M_HEFRAG}" },
          [3] = { num = 4, CLSID = "{ORO57K_S5M_HEFRAG}" },
          [4] = { num = 3, CLSID = "{ORO57K_S5M_HEFRAG}" },
          [5] = { num = 2, CLSID = "{ORO57K_S5M_HEFRAG}" },
          [6] = { num = 1, CLSID = "{K-13A}" },
        }
      },
      {
        name = "BombFull",
        pylons = {
          [1] = { num = 6, CLSID = "{K-13A}" },
          [2] = { num = 5, CLSID = "{3C612111-C7AD-476E-8A8E-2485812F4E5C}" },
          [3] = { num = 2, CLSID = "{3C612111-C7AD-476E-8A8E-2485812F4E5C}" },
          [4] = { num = 1, CLSID = "{K-13A}" },
        }
      },
    }
  },

  {
    unitType = "MiG-21Bis",  -- <- exact DCS type string
    payloads = {
      {
        name = "Air2AirFull",
        pylons = {
          [1] = { num = 6, CLSID = "{ASO-2}" },
          [2] = { num = 5, CLSID = "{R-60 2R}" },
          [3] = { num = 1, CLSID = "{R-60 2L}" },
        }
      },
      {
        name = "Nuke",
        pylons = {
          [1] = { num = 6, CLSID = "{ASO-2}" },
          [2] = { num = 5, CLSID = "{PTB_490_MIG21}" },
          [3] = { num = 3, CLSID = "{RN-24}" },
          [4] = { num = 1, CLSID = "{PTB_490_MIG21}" },
        }
      },
      {
        name = "AGRockets",
        pylons = {
          [1] = { num = 6, CLSID = "{ASO-2}" },
          [2] = { num = 5, CLSID = "{S-24B}" },
          [3] = { num = 4, CLSID = "{S-24B}" },
          [4] = { num = 3, CLSID = "{PTB_490C_MIG21}" },
          [5] = { num = 2, CLSID = "{S-24B}" },
          [6] = { num = 1, CLSID = "{S-24B}" },
        }
      },
      {
        name = "BombFull",
        pylons = {
          [1] = { num = 6, CLSID = "{ASO-2}" },
          [2] = { num = 5, CLSID = "{3C612111-C7AD-476E-8A8E-2485812F4E5C}" },
          [3] = { num = 4, CLSID = "{3C612111-C7AD-476E-8A8E-2485812F4E5C}" },
          [4] = { num = 3, CLSID = "{PTB_490C_MIG21}" },
          [5] = { num = 2, CLSID = "{3C612111-C7AD-476E-8A8E-2485812F4E5C}" },
          [6] = { num = 1, CLSID = "{3C612111-C7AD-476E-8A8E-2485812F4E5C}" },
        }
      },
    }
  },

  {
    unitType = "MiG-23MLD",  -- <- exact DCS type string
    payloads = {
      {
        name = "Air2AirFull",
        pylons = {
          [1] = { num = 6, CLSID = "{CCF898C9-5BC7-49A4-9D1E-C3ED3D5166A1}" },
          [2] = { num = 5, CLSID = "{R-60 2R}" },
          [3] = { num = 4, CLSID = "{A5BAEAB7-6FAF-4236-AF72-0FD900F493F9}" },
          [4] = { num = 3, CLSID = "{R-60 2L}" },
          [5] = { num = 2, CLSID = "{CCF898C9-5BC7-49A4-9D1E-C3ED3D5166A1}" },
        }
      },
      {
        name = "AGRockets",
        pylons = {
          [1] = { num = 6, CLSID = "{UB32A_S5KP}" },
          [2] = { num = 5, CLSID = "{UB32A_S5KP}" },
          [3] = { num = 4, CLSID = "{A5BAEAB7-6FAF-4236-AF72-0FD900F493F9}" },
          [4] = { num = 3, CLSID = "{UB32A_S5KP}" },
          [5] = { num = 2, CLSID = "{UB32A_S5KP}" },
        }
      },
      {
        name = "BombFull",
        pylons = {
          [1] = { num = 6, CLSID = "{7AEC222D-C523-425e-B714-719C0D1EB14D}" },
          [2] = { num = 5, CLSID = "{7AEC222D-C523-425e-B714-719C0D1EB14D}" },
          [3] = { num = 4, CLSID = "{A5BAEAB7-6FAF-4236-AF72-0FD900F493F9}" },
          [4] = { num = 3, CLSID = "{7AEC222D-C523-425e-B714-719C0D1EB14D}" },
          [5] = { num = 2, CLSID = "{7AEC222D-C523-425e-B714-719C0D1EB14D}" },
        }
      },
    }
  },

  {
    unitType = "MiG-29A",  -- <- exact DCS type string
    payloads = {
      {
        name = "Air2AirFull",
        pylons = {
          [1] = { num = 7, CLSID = "{R_60}" },
          [2] = { num = 6, CLSID = "{R_60}" },
          [3] = { num = 5, CLSID = "{E8069896-8435-4B90-95C0-01A03AE6E400}" },
          [4] = { num = 4, CLSID = "{2BEC576B-CDF5-4B7F-961F-B0FA4312B841}" },
          [5] = { num = 3, CLSID = "{E8069896-8435-4B90-95C0-01A03AE6E400}" },
          [6] = { num = 2, CLSID = "{R_60}" },
          [7] = { num = 1, CLSID = "{R_60}" },
        }
      },
      {
        name = "AGRockets",
        pylons = {
          [1] = { num = 7, CLSID = "{R_60}" },
          [2] = { num = 6, CLSID = "{F72F47E5-C83A-4B85-96ED-D3E46671EE9A}" },
          [3] = { num = 5, CLSID = "{F72F47E5-C83A-4B85-96ED-D3E46671EE9A}" },
          [4] = { num = 4, CLSID = "{2BEC576B-CDF5-4B7F-961F-B0FA4312B841}" },
          [5] = { num = 3, CLSID = "{F72F47E5-C83A-4B85-96ED-D3E46671EE9A}" },
          [6] = { num = 2, CLSID = "{F72F47E5-C83A-4B85-96ED-D3E46671EE9A}" },
          [7] = { num = 1, CLSID = "{R_60}" },
        }
      },
      {
        name = "BombFull",
        pylons = {
          [1] = { num = 7, CLSID = "{R_60}" },
          [2] = { num = 6, CLSID = "{7AEC222D-C523-425e-B714-719C0D1EB14D}" },
          [3] = { num = 5, CLSID = "{7AEC222D-C523-425e-B714-719C0D1EB14D}" },
          [4] = { num = 4, CLSID = "{2BEC576B-CDF5-4B7F-961F-B0FA4312B841}" },
          [5] = { num = 3, CLSID = "{7AEC222D-C523-425e-B714-719C0D1EB14D}" },
          [6] = { num = 2, CLSID = "{7AEC222D-C523-425e-B714-719C0D1EB14D}" },
          [7] = { num = 1, CLSID = "{R_60}" },
        }
      },
    }
  },

  {
    unitType = "MiG-31",  -- <- exact DCS type string
    payloads = {
      {
        name = "Air2AirFull",
        pylons = {
          [1] = { num = 6, CLSID = "{R-60 2R}" },
          [2] = { num = 5, CLSID = "{F1243568-8EF0-49D4-9CB5-4DA90D92BC1D}" },
          [3] = { num = 4, CLSID = "{F1243568-8EF0-49D4-9CB5-4DA90D92BC1D}" },
          [4] = { num = 3, CLSID = "{F1243568-8EF0-49D4-9CB5-4DA90D92BC1D}" },
          [5] = { num = 2, CLSID = "{F1243568-8EF0-49D4-9CB5-4DA90D92BC1D}" },
          [6] = { num = 1, CLSID = "{R-60 2L}" },
        }
      },
    }
  },

  {
    unitType = "Su-25T",  -- <- exact DCS type string
    payloads = {
      {
        name = "BombFull",
        pylons = {
          [1]  = { num = 11, CLSID = "{R_60}" },
          [2]  = { num = 10, CLSID = "{37DCC01E-9E02-432F-B61D-10C166CA2798}" },
          [3]  = { num = 9,  CLSID = "{37DCC01E-9E02-432F-B61D-10C166CA2798}" },
          [4]  = { num = 8,  CLSID = "{37DCC01E-9E02-432F-B61D-10C166CA2798}" },
          [5]  = { num = 7,  CLSID = "{37DCC01E-9E02-432F-B61D-10C166CA2798}" },
          [6]  = { num = 5,  CLSID = "{37DCC01E-9E02-432F-B61D-10C166CA2798}" },
          [7]  = { num = 4,  CLSID = "{37DCC01E-9E02-432F-B61D-10C166CA2798}" },
          [8]  = { num = 3,  CLSID = "{37DCC01E-9E02-432F-B61D-10C166CA2798}" },
          [9]  = { num = 2,  CLSID = "{37DCC01E-9E02-432F-B61D-10C166CA2798}" },
          [10] = { num = 1,  CLSID = "{R_60}" },
        }
      },
      {
        name = "AGRockets",
        pylons = {
          [1]  = { num = 11, CLSID = "{R_60}" },
          [2]  = { num = 10, CLSID = "{UB32A_S5KP}" },
          [3]  = { num = 9,  CLSID = "{UB32A_S5KP}" },
          [4]  = { num = 8,  CLSID = "{UB32A_S5KP}" },
          [5]  = { num = 7,  CLSID = "{UB32A_S5KP}" },
          [6]  = { num = 5,  CLSID = "{UB32A_S5KP}" },
          [7]  = { num = 4,  CLSID = "{UB32A_S5KP}" },
          [8]  = { num = 3,  CLSID = "{UB32A_S5KP}" },
          [9]  = { num = 2,  CLSID = "{UB32A_S5KP}" },
          [10] = { num = 1,  CLSID = "{R_60}" },
        }
      },
      {
        name = "AGMissiles",
        pylons = {
          [1]  = { num = 11, CLSID = "{R_60}" },
          [2]  = { num = 10, CLSID = "{0180F983-C14A-11d8-9897-000476191836}" },
          [3]  = { num = 9,  CLSID = "{0180F983-C14A-11d8-9897-000476191836}" },
          [4]  = { num = 8,  CLSID = "{0180F983-C14A-11d8-9897-000476191836}" },
          [5]  = { num = 7,  CLSID = "{0180F983-C14A-11d8-9897-000476191836}" },
          [6]  = { num = 6,  CLSID = "{B1EF6B0E-3D91-4047-A7A5-A99E7D8B4A8B}" },
          [7]  = { num = 5,  CLSID = "{0180F983-C14A-11d8-9897-000476191836}" },
          [8]  = { num = 4,  CLSID = "{0180F983-C14A-11d8-9897-000476191836}" },
          [9]  = { num = 3,  CLSID = "{0180F983-C14A-11d8-9897-000476191836}" },
          [10] = { num = 2,  CLSID = "{0180F983-C14A-11d8-9897-000476191836}" },
          [11] = { num = 1,  CLSID = "{R_60}" },
        }
      },
    }
  },

  {
    unitType = "Su-27",  -- <- exact DCS type string
    payloads = {
      {
        name = "Air2AirFull",
        pylons = {
          [1] = { num = 10, CLSID = "{44EE8698-89F9-48EE-AF36-5FD31896A82A}" },
          [2] = { num = 8,  CLSID = "{E8069896-8435-4B90-95C0-01A03AE6E400}" },
          [3] = { num = 7,  CLSID = "{E8069896-8435-4B90-95C0-01A03AE6E400}" },
          [4] = { num = 6,  CLSID = "{E8069896-8435-4B90-95C0-01A03AE6E400}" },
          [5] = { num = 5,  CLSID = "{E8069896-8435-4B90-95C0-01A03AE6E400}" },
          [6] = { num = 4,  CLSID = "{E8069896-8435-4B90-95C0-01A03AE6E400}" },
          [7] = { num = 3,  CLSID = "{E8069896-8435-4B90-95C0-01A03AE6E400}" },
          [8] = { num = 1,  CLSID = "{44EE8698-89F9-48EE-AF36-5FD31896A82F}" },
        }
      },
    }
  },

  {
    unitType = "B-52H",  -- <- exact DCS type string
    payloads = {
      {
        name = "BombFull",
        pylons = {
          [1] = { num = 3, CLSID = "{696CFFC4-0BDE-42A8-BE4B-0BE3D9DD723C}" },
          [2] = { num = 2, CLSID = "{B52H_BAY_M117}" },
          [3] = { num = 1, CLSID = "{696CFFC4-0BDE-42A8-BE4B-0BE3D9DD723C}" },
        }
      },
    }
  },

  {
    unitType = "Tu-22M3",  -- <- exact DCS type string
    payloads = {
      {
        name = "BombFull",
        pylons = {
          [1] = { num = 5, CLSID = "{E1AAE713-5FC3-4CAA-9FF5-3FDCFB899E33}" },
          [2] = { num = 4, CLSID = "{E1AAE713-5FC3-4CAA-9FF5-3FDCFB899E33}" },
          [3] = { num = 3, CLSID = "{AD5E5863-08FC-4283-B92C-162E2B2BD3FF}" },
          [4] = { num = 2, CLSID = "{E1AAE713-5FC3-4CAA-9FF5-3FDCFB899E33}" },
          [5] = { num = 1, CLSID = "{E1AAE713-5FC3-4CAA-9FF5-3FDCFB899E33}" },
        }
      },
    }
  },

  {
    unitType = "UH-1H",  -- <- exact DCS type string
    payloads = {
      {
        name = "AGRockets",
        pylons = {
          [1] = { num = 6, CLSID = "{M134_R}" },
          [2] = { num = 5, CLSID = "{M261_MK151}" },
          [3] = { num = 2, CLSID = "{M261_MK151}" },
          [4] = { num = 1, CLSID = "{M134_L}" },
        }
      },
      {
        name = "Troops",
        pylons = {
          [1] = { num = 4, CLSID = "{M60_SIDE_R}" },
          [2] = { num = 3, CLSID = "{M60_SIDE_L}" },
        }
      },
    }
  },

  {
    unitType = "Mi-24P",  -- <- exact DCS type string
    payloads = {
      {
        name = "Air2AirFull",
        pylons = {
          [1] = { num = 6, CLSID = "{2x9M220_Ataka_V}" },
          [2] = { num = 5, CLSID = "{275A2855-4A79-4B2D-B082-91EA2ADF4691}" },
          [3] = { num = 4, CLSID = "{GUV_YakB_GSHP}" },
          [4] = { num = 3, CLSID = "{GUV_YakB_GSHP}" },
          [5] = { num = 2, CLSID = "{B0DBC591-0F52-4F7D-AD7B-51E67725FB81}" },
          [6] = { num = 1, CLSID = "{2x9M220_Ataka_V}" },
        }
      },
      {
        name = "AGRockets",
        pylons = {
          [1] = { num = 6, CLSID = "{2x9M220_Ataka_V}" },
          [2] = { num = 5, CLSID = "{UB-32A-24}" },
          [3] = { num = 4, CLSID = "{UB-32A-24}" },
          [4] = { num = 3, CLSID = "{UB-32A-24}" },
          [5] = { num = 2, CLSID = "{UB-32A-24}" },
          [6] = { num = 1, CLSID = "{2x9M220_Ataka_V}" },
        }
      },
      {
        name = "AGMissiles",
        pylons = {
          [1] = { num = 6, CLSID = "{B919B0F4-7C25-455E-9A02-CEA51DB895E3}" },
          [2] = { num = 5, CLSID = "{2x9M114_with_adapter}" },
          [3] = { num = 4, CLSID = "{GUV_VOG}" },
          [4] = { num = 3, CLSID = "{GUV_VOG}" },
          [5] = { num = 2, CLSID = "{2x9M114_with_adapter}" },
          [6] = { num = 1, CLSID = "{B919B0F4-7C25-455E-9A02-CEA51DB895E3}" },
        }
      },
      {
        name = "Troops",
        pylons = {
          [1] = { num = 7, CLSID = "{KORD_12_7_MI24_L}" },
          [2] = { num = 6, CLSID = "{2x9M220_Ataka_V}" },
          [3] = { num = 5, CLSID = "{B_8V20A_OM}" },
          [4] = { num = 2, CLSID = "{B_8V20A_OM}" },
          [5] = { num = 1, CLSID = "{2x9M220_Ataka_V}" },
        }
      },
    }
  },

  {
    unitType = "Mi-8MT",  -- <- exact DCS type string
    payloads = {
      {
        name = "AGRockets",
        pylons = {
          [1] = { num = 8, CLSID = "{PKT_7_62}" },
          [2] = { num = 7, CLSID = "{KORD_12_7}" },
          [3] = { num = 6, CLSID = "{6A4B9E69-64FE-439a-9163-3A87FB6A4D81}" },
          [4] = { num = 5, CLSID = "{6A4B9E69-64FE-439a-9163-3A87FB6A4D81}" },
          [5] = { num = 4, CLSID = "{6A4B9E69-64FE-439a-9163-3A87FB6A4D81}" },
          [6] = { num = 3, CLSID = "{6A4B9E69-64FE-439a-9163-3A87FB6A4D81}" },
          [7] = { num = 2, CLSID = "{6A4B9E69-64FE-439a-9163-3A87FB6A4D81}" },
          [8] = { num = 1, CLSID = "{6A4B9E69-64FE-439a-9163-3A87FB6A4D81}" },
        }
      },
      {
        name = "Transport",
        pylons = {}
      },
      {
        name = "Troops",
        pylons = {
          [1] = { num = 8, CLSID = "{PKT_7_62}" },
          [2] = { num = 7, CLSID = "{KORD_12_7}" },
          [3] = { num = 6, CLSID = "{B_8V20A_CM_WH}" },
          [4] = { num = 1, CLSID = "{B_8V20A_CM_WH}" },
        }
      },
    }
  },

  {
    unitType = "CH-47Fbl1",  -- <- exact DCS type string
    payloads = {
      {
        name = "Transport",
        pylons = {
          [1] = { num = 2, CLSID = "{CH47_STBD_M240H}" },
          [2] = { num = 1, CLSID = "{CH47_PORT_M240H}" },
        }
      },
      {
        name = "Troops",
        pylons = {
          [1] = { num = 3, CLSID = "{CH47_AFT_M240H}" },
          [2] = { num = 2, CLSID = "{CH47_STBD_M240H}" },
          [3] = { num = 1, CLSID = "{CH47_PORT_M240H}" },
        }
      },
    }
  },
}
-- END CATALOG

---------------------------------------------------------------------
-- 2) Build fast index: PYLON_PRESETS[unitType][presetName] = { pylons = { [station] = {num=, CLSID=}... }, fuel/chaff/flare/gun? }
---------------------------------------------------------------------
PYLON_PRESETS = PYLON_PRESETS or {}

local function log(msg) if env and env.info then env.info("[PYLONS] "..tostring(msg)) end end
local function warn(msg)
  if env and env.warning then env.warning("[PYLONS] "..tostring(msg)) end
  if env and env.info then env.info("[PYLONS][WARN] "..tostring(msg)) end
end

local function isPylonEntry(v) return type(v)=="table" and type(v.CLSID)=="string" and (type(v.num)=="number") end

local function normalizeOnePayload(unitType, pset)
  -- Ensure stations are keyed by *station number* (not arbitrary array index)
  local out = { pylons = {}, fuel = pset.fuel, chaff = pset.chaff, flare = pset.flare, gun = pset.gun }
  if type(pset.pylons)=="table" then
    for k,v in pairs(pset.pylons) do
      if isPylonEntry(v) then
        local st = tonumber(v.num)
        if st then
          if out.pylons[st] then
            warn(("Duplicate station %s on %s/%s; keeping first CLSID=%s, dropping=%s")
                :format(st, unitType, tostring(pset.name), out.pylons[st].CLSID, v.CLSID))
          else
            out.pylons[st] = { CLSID=v.CLSID, num=st }
          end
        end
      else
        warn(("Bad pylon entry on %s/%s: key=%s"):format(unitType, tostring(pset.name), tostring(k)))
      end
    end
  end
  return out
end

local function buildIndex()
  local added, types = 0, 0
  for _,rec in ipairs(PYLONS or {}) do
    local utype = rec.unitType
    if type(utype)=="string" and type(rec.payloads)=="table" then
      PYLON_PRESETS[utype] = PYLON_PRESETS[utype] or {}
      types = types + 1
      for _,pset in ipairs(rec.payloads) do
        if type(pset)=="table" and type(pset.name)=="string" then
          PYLON_PRESETS[utype][pset.name] = normalizeOnePayload(utype, pset)
          added = added + 1
        end
      end
    end
  end
  log(("Indexed %d presets across %d unit types."):format(added, types))
end

buildIndex()

---------------------------------------------------------------------
-- 3) Runtime applier (best-effort; harmless if DCS disallows mutating payloads)
---------------------------------------------------------------------
-- Strategy:
--   • If group exists, we try a controller:setCommand with an internal "Loadout" id (many missions use this),
--     fully wrapped in pcall so it NOOPs if not supported on your DCS branch/map.
--   • If that fails, we return false. LOADOUT.lua is already coded to treat that as a safe no-op.

local function makeLoadoutTask(unitType, presetName)
  local preset = PYLON_PRESETS[unitType] and PYLON_PRESETS[unitType][presetName]
  if not preset then return nil end

  -- Convert our preset into DCS "payload" schema expected by the command/task.
  local payload = { pylons = {}, fuel = preset.fuel, chaff = preset.chaff, flare = preset.flare, gun = preset.gun }
  for st, p in pairs(preset.pylons) do payload.pylons[#payload.pylons+1] = { num=st, CLSID=p.CLSID } end

  -- Some DCS builds accept a "Loadout" *command*, others a "Payload" *task*. We'll try both.
  local cmd = { id = "Loadout", params = { payload = payload } }
  local tsk = { id = "Payload", params = { payload = payload } }
  return cmd, tsk
end

function PYLONS.applyForGroup(groupName, presetName)
  local g = Group.getByName(groupName)
  if not g or not g:isExist() then return false end

  -- Determine unit type from the first unit
  local u = g:getUnit(1); if not (u and u.isExist and u:isExist()) then return false end
  local desc = u:getDesc() or {}
  local unitType = u:getTypeName() or desc.typeName or desc.displayName
  if not (unitType and PYLON_PRESETS[unitType] and PYLON_PRESETS[unitType][presetName]) then
    warn(("applyForGroup: preset '%s' not found for type '%s'"):format(tostring(presetName), tostring(unitType)))
    return false
  end

  local ctrl = g:getController(); if not ctrl then return false end
  local cmd, tsk = makeLoadoutTask(unitType, presetName)
  if not cmd then return false end

  -- Try command first
  local ok1 = pcall(function() ctrl:setCommand(cmd) end)
  if ok1 then
    log(("Applied preset '%s' to %s via setCommand."):format(presetName, groupName))
    return true
  end

  -- Try task fallback
  local ok2 = pcall(function() ctrl:setTask(tsk) end)
  if ok2 then
    log(("Applied preset '%s' to %s via setTask."):format(presetName, groupName))
    return true
  end

  warn(("applyForGroup: DCS refused payload change for %s (%s)."):format(groupName, unitType))
  return false
end

---------------------------------------------------------------------
-- Convenience helpers (optional)
---------------------------------------------------------------------
function PYLONS.has(unitType, presetName)
  return (PYLON_PRESETS[unitType] and PYLON_PRESETS[unitType][presetName]) and true or false
end

function PYLONS.list(unitType)
  local out = {}
  for name,_ in pairs(PYLON_PRESETS[unitType] or {}) do out[#out+1] = name end
  table.sort(out); return out
end

pcall(function() trigger.action.outText("[PYLONS] ready: presets indexed.", 5) end)
return PYLONS
