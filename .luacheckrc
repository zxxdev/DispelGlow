-- Lua 5.1, the version of the 3.3.5a client.
std = "lua51"
max_line_length = 120
exclude_files = { ".luarocks", "lua_modules" }

-- What the addon defines for the game: only the slash command.
globals = {
    "SLASH_DISPELGLOW1",
    "SLASH_DISPELGLOW2",
    "SlashCmdList",
}

-- Game API the addon reads.
read_globals = {
    "BOOKTYPE_PET",
    "BOOKTYPE_SPELL",
    "CreateFrame",
    "FocusFrame",
    "GetNumSpellTabs",
    "GetSpellBookItemName",
    "GetSpellInfo",
    "GetSpellName",
    "GetSpellTabInfo",
    "HasPetSpells",
    "MAX_TARGET_BUFFS",
    "TargetFrame",
    "TargetFrame_UpdateAuras",
    "UnitBuff",
    "UnitCanAttack",
    "UnitClass",
    "hooksecurefunc",
}

files["spec/**/*.lua"] = {
    std = "+busted",
    -- The tests play the game API, so they define it.
    globals = { "_G" },
    allow_defined_top = true,
    max_line_length = 130,
}
