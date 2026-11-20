--[[
DispelGlow, for the 3.3.5a client (Wrath of the Lich King).

On an enemy target or focus, the Magic buffs glow with the same border
Blizzard draws for a mage's Spellsteal, but only when your character has a
spell that can remove them:

  Shaman   Purge
  Priest   Dispel Magic, Mass Dispel
  Mage     Spellsteal
  Hunter   Tranquilizing Shot
  Warlock  Devour Magic, while the Felhunter is out

Other classes (and characters too low to have the spell) see no glow.

/dispelglow (or /dglow) says whether it is on, and with which spell.
]]

DispelGlow = DispelGlow or {}
local DG = DispelGlow

-- Spells that remove a Magic effect from an enemy, by the ID of their first
-- rank. Their names are read from the game, so it works in any language, and
-- every rank has the same name.
DG.SPELLS = {
    { id = 370 }, -- Purge (Shaman)
    { id = 527 }, -- Dispel Magic (Priest)
    { id = 32375 }, -- Mass Dispel (Priest)
    { id = 30449 }, -- Spellsteal (Mage)
    { id = 19801 }, -- Tranquilizing Shot (Hunter)
    { id = 19505, pet = true }, -- Devour Magic (Warlock's Felhunter)
}

local BOOK_PLAYER = BOOKTYPE_SPELL or "spell"
local BOOK_PET = BOOKTYPE_PET or "pet"
local MAX_BUFFS = MAX_TARGET_BUFFS or 32

-- 3.3.5a calls it GetSpellName; later clients renamed it.
local function spellBookName(index, book)
    local get = GetSpellBookItemName or GetSpellName
    return get(index, book)
end

-- Names of every spell in the player's spell book.
local function playerSpells()
    local names = {}
    for tab = 1, GetNumSpellTabs() do
        local _, _, offset, count = GetSpellTabInfo(tab)
        for index = offset + 1, offset + count do
            local name = spellBookName(index, BOOK_PLAYER)
            if name then
                names[name] = true
            end
        end
    end
    return names
end

-- Names of every spell the current pet has. None without a pet.
local function petSpells()
    local names = {}
    local count = HasPetSpells()
    for index = 1, count or 0 do
        local name = spellBookName(index, BOOK_PET)
        if name then
            names[name] = true
        end
    end
    return names
end

--- The name of the first spell this character can use to remove Magic from
--- an enemy, or nil if it has none.
function DG.FindDispelSpell()
    local mine, pets = playerSpells(), petSpells()
    for _, spell in ipairs(DG.SPELLS) do
        local name = GetSpellInfo(spell.id)
        local book = spell.pet and pets or mine
        if name and book[name] then
            return name
        end
    end
    return nil
end

--- Called after Blizzard has drawn the buffs of the target or focus frame:
--- shows the glow on every Magic buff of an enemy, if this character can
--- remove it. Blizzard hides the glows again on its next redraw.
function DG.UpdateFrame(frame)
    if not DG.spell or not frame or not frame.unit then
        return
    end
    local unit = frame.unit
    if not UnitCanAttack("player", unit) then
        return
    end
    local prefix = frame:GetName() .. "Buff"
    for index = 1, MAX_BUFFS do
        local name, _, _, _, debuffType = UnitBuff(unit, index)
        if not name then
            break
        end
        if debuffType == "Magic" then
            local glow = _G[prefix .. index .. "Stealable"]
            if glow then
                glow:Show()
            end
        end
    end
end

--- Looks for the spell again and redraws the frames that are on screen.
function DG.Refresh()
    DG.spell = DG.FindDispelSpell()
    for _, frame in ipairs({ TargetFrame, FocusFrame }) do
        if frame and frame:IsShown() then
            TargetFrame_UpdateAuras(frame)
        end
    end
end

-- Hooked after Blizzard's own function, without replacing it, so no other
-- addon or protected part of the interface is affected.
hooksecurefunc("TargetFrame_UpdateAuras", DG.UpdateFrame)

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("SPELLS_CHANGED") -- a spell learned, or a new rank
events:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED") -- dual specialization
events:RegisterEvent("UNIT_PET") -- a pet summoned or dismissed
events:RegisterEvent("PET_BAR_UPDATE") -- the pet's spells are ready
events:SetScript("OnEvent", function(_, event, unit)
    if event == "UNIT_PET" and unit ~= "player" then
        return
    end
    DG.Refresh()
end)

SLASH_DISPELGLOW1 = "/dispelglow"
SLASH_DISPELGLOW2 = "/dglow"
SlashCmdList.DISPELGLOW = function()
    DG.Refresh()
    if DG.spell then
        print("|cff7aa5ffDispelGlow|r: on, with " .. DG.spell .. ".")
    else
        print("|cff7aa5ffDispelGlow|r: off. This character has no spell that removes Magic from an enemy.")
    end
end
