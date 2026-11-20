-- DispelGlow with the game played by tables: each test sets up a character's
-- class, spell book, pet and the target's buffs, loads the addon the way the
-- game does (with its private namespace), logs in and checks what glows.
-- Run with `busted` from the repository root.

local SPELL_NAMES = {
    [370] = "Purge",
    [527] = "Dispel Magic",
    [32375] = "Mass Dispel",
    [30449] = "Spellsteal",
    [19801] = "Tranquilizing Shot",
    [19505] = "Devour Magic",
}

--- A fresh fake game with the addon loaded and logged in.
--- `spells` and `petSpells` are lists of spell names; `buffs` are the
--- target's buffs as { name, debuffType }.
local function setupGame(options)
    local game = { shown = {}, hooks = {}, events = {}, printed = {}, lookups = 0 }
    local spells = options.spells or {}
    game.petSpells = options.petSpells or {}
    local buffs = options.buffs or {}

    _G.BOOKTYPE_SPELL = "spell"
    _G.BOOKTYPE_PET = "pet"
    _G.MAX_TARGET_BUFFS = 32
    _G.SlashCmdList = {}
    _G.GetSpellBookItemName = nil
    _G.print = function(text)
        table.insert(game.printed, text)
    end

    _G.UnitClass = function()
        return "Class", options.class
    end
    _G.GetSpellInfo = function(id)
        return SPELL_NAMES[id]
    end
    _G.GetNumSpellTabs = function()
        return 1
    end
    _G.GetSpellTabInfo = function()
        return "General", "icon", 0, #spells
    end
    _G.GetSpellName = function(index, book)
        if book == "pet" then
            return game.petSpells[index]
        end
        return spells[index]
    end
    _G.HasPetSpells = function()
        if #game.petSpells == 0 then
            return nil
        end
        return #game.petSpells, "DEMON"
    end
    _G.UnitCanAttack = function()
        return options.enemy ~= false
    end
    _G.UnitBuff = function(_, index)
        local buff = buffs[index]
        if not buff then
            return nil
        end
        return buff[1], "rank", "icon", 1, buff[2]
    end

    -- The glow textures, counting how often the addon asks for one.
    local textures = {}
    for index = 1, 32 do
        textures["TargetFrameBuff" .. index .. "Stealable"] = {
            Show = function()
                game.shown[index] = true
            end,
        }
    end
    setmetatable(_G, {
        __index = function(_, key)
            if textures[key] then
                game.lookups = game.lookups + 1
                return textures[key]
            end
        end,
    })

    _G.TargetFrame = {
        unit = "target",
        GetName = function()
            return "TargetFrame"
        end,
        IsShown = function()
            return true
        end,
    }
    _G.FocusFrame = nil
    _G.TargetFrame_UpdateAuras = function(frame)
        game.shown = {}
        for _, hook in ipairs(game.hooks) do
            hook(frame)
        end
    end
    _G.hooksecurefunc = function(name, hook)
        assert(name == "TargetFrame_UpdateAuras")
        table.insert(game.hooks, hook)
    end
    _G.CreateFrame = function()
        local frame = {}
        function frame.RegisterEvent(_, event)
            game.events[event] = true
        end
        function frame.UnregisterEvent(_, event)
            game.events[event] = nil
        end
        function frame.SetScript(_, _, handler)
            game.onEvent = function(event, ...)
                handler(frame, event, ...)
            end
        end
        return frame
    end

    game.ns = {}
    assert(loadfile("DispelGlow.lua"))("DispelGlow", game.ns)
    game.onEvent("PLAYER_LOGIN")
    return game
end

local magicBuffs = {
    { "Power Word: Fortitude", "Magic" },
    { "Bloodlust", "Magic" },
    { "Enrage", nil }, -- not Magic: never glows
}

after_each(function()
    setmetatable(_G, nil)
end)

describe("which characters can remove Magic", function()
    it("a warrior cannot: no glow, no hook and no events at all", function()
        local game = setupGame({ class = "WARRIOR", spells = { "Heroic Strike" }, buffs = magicBuffs })
        assert.is_nil(game.ns.spell)
        assert.same({}, game.hooks)
        assert.same({}, game.events)
    end)

    it("a shaman with Purge can, and stops listening once it is found", function()
        local game = setupGame({ class = "SHAMAN", spells = { "Lightning Bolt", "Purge" }, buffs = magicBuffs })
        assert.equal("Purge", game.ns.spell)
        assert.same({ [1] = true, [2] = true }, game.shown)
        assert.same({}, game.events)
    end)

    it("a low-level shaman keeps listening until Purge is learned", function()
        local game = setupGame({ class = "SHAMAN", spells = { "Lightning Bolt" } })
        assert.is_nil(game.ns.spell)
        assert.is_true(game.events.SPELLS_CHANGED)
    end)

    it("a priest with Dispel Magic can", function()
        local game = setupGame({ class = "PRIEST", spells = { "Smite", "Dispel Magic" } })
        assert.equal("Dispel Magic", game.ns.spell)
    end)

    it("a hunter with Tranquilizing Shot can", function()
        local game = setupGame({ class = "HUNTER", spells = { "Arcane Shot", "Tranquilizing Shot" } })
        assert.equal("Tranquilizing Shot", game.ns.spell)
    end)

    it("a mage is left to the game's own Spellsteal glow", function()
        local game = setupGame({ class = "MAGE", spells = { "Frostbolt", "Spellsteal" }, buffs = magicBuffs })
        assert.same({}, game.hooks)
        assert.same({}, game.events)
        _G.SlashCmdList.DISPELGLOW()
        assert.matches("game's own glow", game.printed[1], 1, true)
    end)

    it("a warlock only while the Felhunter is out, following the pet", function()
        local game = setupGame({ class = "WARLOCK", spells = { "Shadow Bolt" }, buffs = magicBuffs })
        assert.is_nil(game.ns.spell)
        assert.is_true(game.events.UNIT_PET)
        assert.is_nil(game.events.SPELLS_CHANGED)

        game.petSpells[1] = "Devour Magic"
        game.onEvent("UNIT_PET", "player")
        assert.equal("Devour Magic", game.ns.spell)
        assert.same({ [1] = true, [2] = true }, game.shown)

        game.petSpells[1] = "Firebolt" -- the Imp now
        game.onEvent("UNIT_PET", "player")
        assert.is_nil(game.ns.spell)
    end)

    it("a warlock's pet spell does not count from the player's own book", function()
        local game = setupGame({ class = "WARLOCK", spells = { "Devour Magic" } })
        assert.is_nil(game.ns.spell)
    end)

    it("ignores pet events of other units", function()
        local game = setupGame({ class = "WARLOCK", spells = {} })
        game.petSpells[1] = "Devour Magic"
        game.onEvent("UNIT_PET", "party1")
        assert.is_nil(game.ns.spell)
    end)
end)

describe("what glows", function()
    it("only the Magic buffs of an enemy", function()
        local game = setupGame({ class = "PRIEST", spells = { "Dispel Magic" }, buffs = magicBuffs })
        assert.same({ [1] = true, [2] = true }, game.shown)
    end)

    it("nothing on a friendly target", function()
        local game = setupGame({ class = "PRIEST", spells = { "Dispel Magic" }, buffs = magicBuffs, enemy = false })
        assert.same({}, game.shown)
    end)

    it("looks each glow texture up once, however often the buffs are redrawn", function()
        local game = setupGame({ class = "PRIEST", spells = { "Dispel Magic" }, buffs = magicBuffs })
        local first = game.lookups
        for _ = 1, 50 do
            _G.TargetFrame_UpdateAuras(_G.TargetFrame)
        end
        assert.equal(2, first)
        assert.equal(first, game.lookups)
    end)

    it("no longer replaces the game's UnitAura or UnitBuff", function()
        local original = function() end
        _G.UnitAura = original
        setupGame({ class = "SHAMAN", spells = { "Purge" } })
        assert.equal(original, _G.UnitAura)
    end)

    it("leaves nothing global except the slash command", function()
        setupGame({ class = "SHAMAN", spells = { "Purge" } })
        assert.is_nil(rawget(_G, "DispelGlow"))
    end)
end)
