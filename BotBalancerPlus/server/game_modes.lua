-- default game-modes table for use with BotBalancerPlus:
--  stores name, default player count, and enabled or disabled

-- credit: LevelDreadnought

local gameModes = {}

-- to enable or disable a game mode, edit the "enabled" field for each mode
-- that you want to modify

-- true = enabled, false = disabled

gameModes["Mode1"] = {
    name = "SUPREMACY",
    maxPlayers = 40,
    enabled = true,
}

gameModes["Mode3"] = {
    name = "EWOK HUNT",
    maxPlayers = 20,
    enabled = false,
}

gameModes["SpaceBattle"] = {
    name = "STARFIGHTER ASSAULT",
    maxPlayers = 24,
    enabled = false,
}

gameModes["ModeC"] = {
    name = "JETPACK CARGO",
    maxPlayers = 16,
    enabled = false,
}

gameModes["Mode7"] = {
    name = "HERO STARFIGHTERS",
    maxPlayers = 8,
    enabled = false,
}

gameModes["Mode5"] = {
    name = "EXTRACTION",
    maxPlayers = 16,
    enabled = false,
}

gameModes["Mode9"] = {
    name = "CO-OP MISSIONS", -- Co-Op attack
    maxPlayers = 4,
    enabled = false,
}

gameModes["PlanetaryBattles"] = {
    name = "GALACTIC ASSAULT",
    maxPlayers = 40,
    enabled = true,
}

gameModes["Mode6"] = {
    name = "HEROES VERSUS VILLAINS", -- hero showdown
    maxPlayers = 32,
    enabled = false,
}

gameModes["SkirmishSpaceBlast"] = {
    name = "STARFIGHTER BLAST",
    maxPlayers = 20,
    enabled = false,
}

gameModes["Blast"] = {
    name = "BLAST", -- blast used in kyber is "SkirmishBlast"
    maxPlayers = 16,
    enabled = false,
}

gameModes["PlanetaryMissions"] = {
    name = "STRIKE",
    maxPlayers = 16,
    enabled = false,
}

gameModes["ModeDefend"] = {
    name = "CO-OP MISSIONS", -- Co-Op defend
    maxPlayers = 4,
    enabled = false,
}

gameModes["SkirmishSpaceOnslaught"] = {
    name = "STARFIGHTER ONSLAUGHT",
    maxPlayers = 20,
    enabled = false,
}

gameModes["HeroesVersusVillains"] = {
    name = "HEROES VS VILLAINS",
    maxPlayers = 8,
    enabled = true,
}

gameModes["SkirmishBlast"] = {
    name = "BLAST", -- normal blast
    maxPlayers = 20,
    enabled = false,
}

-- BF+ & IOI GameModes

gameModes["IOIHvsVAlt02"] = {
    name = "HEROES VS VILLAINS", -- HvV additional maps
    maxPlayers = 8,
    enabled = false,
}

gameModes["IOIHvsVAlt03"] = {
    name = "HEROES VS VILLAINS", -- HvV additional maps
    maxPlayers = 8,
    enabled = false,
}

gameModes["IOIGANoFun"] = {
    name = "GALACTIC ASSAULT", -- vanilla galactic assault in BF+
    maxPlayers = 40,
    enabled = true,
}

gameModes["IOIGAAlternateMaps"] = {
    name = "GALACTIC ASSAULT", -- galactic assault additional maps
    maxPlayers = 40,
    enabled = true,
}

gameModes["IOISupremacyUnrestricted"] = {
    name = "SUPREMACY UNRESTRICTED",
    maxPlayers = 40,
    enabled = true,
}

gameModes["IOIRvsRAlt01"] = {
    name = "REINFORCEMENT CLASH", -- reinforcement clash
    maxPlayers = 8,
    enabled = false,
}

gameModes["IOIRvsRAlt02"] = {
    name = "REINFORCEMENT CLASH", -- reinforcement clash additional maps
    maxPlayers = 8,
    enabled = false,
}

gameModes["IOIRvsRAlt03"] = {
    name = "REINFORCEMENT CLASH", -- reinforcement clash additional maps
    maxPlayers = 8,
    enabled = false,
}

gameModes["IOIHeroExtraction"] = {
    name = "HERO EXTRACTION",
    maxPlayers = 16,
    enabled = false,
}

gameModes["IOITurningPoint"] = {
    name = "TURNING POINT",
    maxPlayers = 40,
    enabled = false,
}

-- game-mode to player count map
local modeToPlayerCountMap = {
    Mode1 = "Supremacy",
    Mode3 = "EwokHunt",
    ModeC = "JetpackCargo",
    Mode5 = "Extraction",
    Mode9 = "CoOp",
    ModeDefend = "CoOp",
    PlanetaryBattles = "GalacticAssault",
    HeroesVersusVillains = "HvV",
    Blast = "Blast",
    SkirmishBlast = "Blast",
    PlanetaryMissions = "Strike",
    IOIHvsVAlt02 = "HvV",
    IOIHvsVAlt03 = "HvV",
    IOIGANoFun = "GalacticAssault",
    IOIGAAlternateMaps = "GalacticAssault",
    IOISupremacyUnrestricted = "SupremacyUr",
    IOIRvsRAlt01 = "ReinforcementClash",
    IOIRvsRAlt02 = "ReinforcementClash",
    IOIRvsRAlt03 = "ReinforcementClash",
    IOIHeroExtraction = "HeroExtraction",
    IOITurningPoint = "TurningPoint"
}

return {
    gameModes = gameModes,
    modeToPlayerCountMap = modeToPlayerCountMap
}