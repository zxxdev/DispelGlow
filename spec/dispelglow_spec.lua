-- DispelGlow with the game played by tables: each test sets up a character's
-- spell book, its pet and the target's buffs, loads the addon and checks what
-- glows. Run with `busted` from the repository root.

local SPELL_NAMES = {
    [370] = "Purge",
    [527] = "Dispel Magic",
    [32375] = "Mass Dispel",
    [30449] = "Spellsteal",
    [19801] = "Tranquilizing Shot",
    [19505] = "Devour Magic",
}

--- A fresh fake game. `spells` and `petSpells` are lists of spell names;
--- `buffs` are the target's buffs as { name, debuffType }.
local function setupGame(options)
    local game = { glows = {}, shown = {}, hooks = {}, events = {} }
    local spells = options.spells or {}
    local petSpells = options.petSpells or {}
    local buffs = options.buffs or {}

    _G.BOOKTYPE_SPELL = "spell"
    _G.BOOKTYPE_PET = "pet"
    _G.MAX_TARGET_BUFFS = 32
    _G.SlashCmdList = {}
    _G.GetSpellBookItemName = nil

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
            return petSpells[index]
        end
        return spells[index]
    end
    _G.HasPetSpells = function()
        if #petSpells == 0 then
            return nil
        end
        return #petSpells, "DEMON"
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

    for index = 1, 32 do
        local glow = {}
        function glow.Show()
            game.shown[index] = true
        end
        _G["TargetFrameBuff" .. index .. "Stealable"] = glow
    end
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
        for _, hook in ipairs(game.hooks) do
            hook(frame)
        end
    end
    _G.hooksecurefunc = function(name, hook)
        assert(name == "TargetFrame_UpdateAuras")
        table.insert(game.hooks, hook)
    end
    _G.CreateFrame = function()
        return {
            RegisterEvent = function(_, event)
                game.events[event] = true
            end,
            SetScript = function(_, _, handler)
                game.onEvent = handler
            end,
        }
    end

    _G.DispelGlow = nil
    dofile("DispelGlow.lua")
    game.addon = _G.DispelGlow
    return game
end

local magicBuffs = {
    { "Power Word: Fortitude", "Magic" },
    { "Bloodlust", "Magic" },
    { "Enrage", nil }, -- not Magic: never glows
}

describe("which characters can remove Magic", function()
    it("a warrior cannot: no glow at all", function()
        local game = setupGame({ spells = { "Heroic Strike", "Shattering Throw" }, buffs = magicBuffs })
        game.onEvent(nil, "PLAYER_LOGIN")
        assert.is_nil(game.addon.spell)
        assert.same({}, game.shown)
    end)

    it("a shaman with Purge can", function()
        local game = setupGame({ spells = { "Lightning Bolt", "Purge" }, buffs = magicBuffs })
        game.onEvent(nil, "PLAYER_LOGIN")
        assert.equal("Purge", game.addon.spell)
    end)

    it("a priest with Dispel Magic can", function()
        local game = setupGame({ spells = { "Smite", "Dispel Magic" } })
        assert.equal("Dispel Magic", game.addon.FindDispelSpell())
    end)

    it("a hunter with Tranquilizing Shot can", function()
        local game = setupGame({ spells = { "Arcane Shot", "Tranquilizing Shot" } })
        assert.equal("Tranquilizing Shot", game.addon.FindDispelSpell())
    end)

    it("a mage with Spellsteal can", function()
        local game = setupGame({ spells = { "Frostbolt", "Spellsteal" } })
        assert.equal("Spellsteal", game.addon.FindDispelSpell())
    end)

    it("a warlock can only while the Felhunter is out", function()
        local withImp = setupGame({ spells = { "Shadow Bolt" }, petSpells = { "Firebolt" } })
        assert.is_nil(withImp.addon.FindDispelSpell())

        local withFelhunter = setupGame({ spells = { "Shadow Bolt" }, petSpells = { "Devour Magic" } })
        assert.equal("Devour Magic", withFelhunter.addon.FindDispelSpell())
    end)

    it("a low-level shaman without Purge yet cannot", function()
        local game = setupGame({ spells = { "Lightning Bolt", "Earth Shock" } })
        assert.is_nil(game.addon.FindDispelSpell())
    end)

    it("a pet's spell does not count as the player's", function()
        -- Devour Magic only counts from the pet's book, not the player's.
        local game = setupGame({ spells = { "Devour Magic" } })
        assert.is_nil(game.addon.FindDispelSpell())
    end)
end)

describe("what glows", function()
    it("only the Magic buffs of an enemy", function()
        local game = setupGame({ spells = { "Purge" }, buffs = magicBuffs })
        game.onEvent(nil, "PLAYER_LOGIN")
        assert.same({ [1] = true, [2] = true }, game.shown)
    end)

    it("nothing on a friendly target", function()
        local game = setupGame({ spells = { "Purge" }, buffs = magicBuffs, enemy = false })
        game.onEvent(nil, "PLAYER_LOGIN")
        assert.same({}, game.shown)
    end)

    it("follows the pet: the glow appears once the Felhunter is summoned", function()
        local game = setupGame({ spells = { "Shadow Bolt" }, buffs = magicBuffs })
        game.onEvent(nil, "PLAYER_LOGIN")
        assert.same({}, game.shown)

        -- Summon the Felhunter: its spells arrive with the pet events.
        _G.HasPetSpells = function()
            return 1, "DEMON"
        end
        _G.GetSpellName = function(index, book)
            if book == "pet" and index == 1 then
                return "Devour Magic"
            end
            return nil
        end
        game.onEvent(nil, "UNIT_PET", "player")
        assert.equal("Devour Magic", game.addon.spell)
        assert.same({ [1] = true, [2] = true }, game.shown)
    end)

    it("ignores pet events of other units", function()
        local game = setupGame({ spells = { "Purge" }, buffs = magicBuffs })
        game.onEvent(nil, "UNIT_PET", "party1")
        assert.is_nil(game.addon.spell)
    end)

    it("listens to the events that change spells, talents and pets", function()
        local game = setupGame({})
        for _, event in ipairs({
            "PLAYER_LOGIN",
            "SPELLS_CHANGED",
            "ACTIVE_TALENT_GROUP_CHANGED",
            "UNIT_PET",
            "PET_BAR_UPDATE",
        }) do
            assert.is_true(game.events[event], event)
        end
    end)

    it("no longer replaces the game's UnitAura or UnitBuff", function()
        local original = function() end
        _G.UnitAura = original
        setupGame({})
        assert.equal(original, _G.UnitAura)
    end)
end)
