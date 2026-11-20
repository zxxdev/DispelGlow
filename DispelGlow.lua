--[[
DispelGlow, for the 3.3.5a client (Wrath of the Lich King).

On an enemy target or focus, the Magic buffs glow with the same border
Blizzard draws for a mage's Spellsteal, but only when your character has a
spell that can remove them:

  Shaman   Purge
  Priest   Dispel Magic, Mass Dispel
  Hunter   Tranquilizing Shot
  Warrior  Shield Slam
  Warlock  Devour Magic, while the Felhunter is out

A mage's Spellsteal already has this glow in the game, on exactly the buffs
that can be stolen, so DispelGlow leaves it to the game. Other classes (and
characters too low to have the spell) see no glow. Only enemies: a friendly
target or focus never glows.

Built to cost as little as possible in the game:
  - A class that cannot remove Magic hooks nothing and listens to nothing.
  - The spell is looked for until it is found, then the addon stops looking
    until the talents change; a warlock only follows its pet.
  - Glow textures are looked up once and kept, so redrawing the buffs makes
    no new strings or tables.
  - Nothing global except the slash command.

/dispelglow (or /dglow) says whether it is on, and with which spell.
]]

local _, ns = ...

-- Spells that remove a Magic effect from an enemy, by the ID of their first
-- rank. Their names are read from the game, so it works in any language, and
-- every rank has the same name.
local PLAYER_SPELLS = {
    SHAMAN = { 370 }, -- Purge
    PRIEST = { 527, 32375 }, -- Dispel Magic, Mass Dispel
    HUNTER = { 19801 }, -- Tranquilizing Shot
    WARRIOR = { 23922 }, -- Shield Slam
}
local PET_SPELLS = {
    WARLOCK = { 19505 }, -- Devour Magic (Felhunter)
}
-- The game already draws this class's glow itself.
local NATIVE = { MAGE = "Spellsteal" }

local BOOK_PLAYER = BOOKTYPE_SPELL or "spell"
local BOOK_PET = BOOKTYPE_PET or "pet"
local MAX_BUFFS = MAX_TARGET_BUFFS or 32
local MAGIC = "Magic"
-- 3.3.5a calls it GetSpellName; later clients renamed it.
local spellBookName = GetSpellBookItemName or GetSpellName
local UnitBuff, UnitCanAttack, _G = UnitBuff, UnitCanAttack, _G

local wanted -- localized names of the spells this class uses
local fromPet -- true when they are in the pet's book (warlock)
local glows = {} -- glows[frame][index]: the frame's glow textures, found once

--- The first wanted name found in a spell book range, or nil.
local function findIn(book, first, last)
    for index = first, last do
        local name = spellBookName(index, book)
        for i = 1, #wanted do
            if name == wanted[i] then
                return name
            end
        end
    end
    return nil
end

--- The spell this character can use right now, or nil.
local function findSpell()
    if fromPet then
        return findIn(BOOK_PET, 1, HasPetSpells() or 0)
    end
    for tab = 1, GetNumSpellTabs() do
        local _, _, offset, count = GetSpellTabInfo(tab)
        local name = findIn(BOOK_PLAYER, offset + 1, offset + count)
        if name then
            return name
        end
    end
    return nil
end

--- The glow texture of one buff button, looked up only the first time.
local function glowOf(frame, index)
    local list = glows[frame]
    if not list then
        list = {}
        glows[frame] = list
    end
    local glow = list[index]
    if glow == nil then
        glow = _G[frame:GetName() .. "Buff" .. index .. "Stealable"] or false
        list[index] = glow
    end
    return glow
end

--- Called after Blizzard has drawn the buffs of the target or focus frame:
--- shows the glow on every Magic buff of an enemy. Blizzard hides the glows
--- again on its next redraw.
function ns.UpdateFrame(frame)
    local unit = ns.spell and frame.unit
    if not unit or not UnitCanAttack("player", unit) then
        return
    end
    for index = 1, MAX_BUFFS do
        local name, _, _, _, debuffType = UnitBuff(unit, index)
        if not name then
            return
        end
        if debuffType == MAGIC then
            local glow = glowOf(frame, index)
            if glow then
                glow:Show()
            end
        end
    end
end

--- Looks for the spell again and redraws the frames that are on screen.
function ns.Refresh()
    ns.spell = findSpell()
    if TargetFrame:IsShown() then
        TargetFrame_UpdateAuras(TargetFrame)
    end
    if FocusFrame and FocusFrame:IsShown() then
        TargetFrame_UpdateAuras(FocusFrame)
    end
end

local events = CreateFrame("Frame")
ns.events = events

events:SetScript("OnEvent", function(self, event, unit)
    if event == "PLAYER_LOGIN" then
        self:UnregisterEvent(event)
        ns.Start(select(2, UnitClass("player")))
    elseif event == "UNIT_PET" and unit ~= "player" then
        return
    elseif event == "PLAYER_TALENT_UPDATE" or event == "ACTIVE_TALENT_GROUP_CHANGED" then
        -- A respec or a dual spec swap can take a spell away or give it back:
        -- look now, and again once the game has rebuilt the spell book.
        ns.Refresh()
        self:RegisterEvent("SPELLS_CHANGED")
    else
        ns.Refresh()
        -- Found: stop looking until the talents change.
        if ns.spell and not fromPet then
            self:UnregisterEvent("SPELLS_CHANGED")
        end
    end
end)
events:RegisterEvent("PLAYER_LOGIN")

--- Sets the addon up for a class, once, at login.
function ns.Start(class)
    ns.class = class
    local ids = PLAYER_SPELLS[class] or PET_SPELLS[class]
    if not ids then
        return -- nothing to do for this class: no hook, no events
    end
    fromPet = PET_SPELLS[class] ~= nil
    wanted = {}
    for i = 1, #ids do
        wanted[#wanted + 1] = GetSpellInfo(ids[i])
    end

    -- After Blizzard's own function, without replacing it, so no other addon
    -- or protected part of the interface is affected.
    hooksecurefunc("TargetFrame_UpdateAuras", ns.UpdateFrame)
    if fromPet then
        events:RegisterEvent("UNIT_PET") -- the pet summoned or dismissed
        events:RegisterEvent("PET_BAR_UPDATE") -- its spells are ready
    else
        events:RegisterEvent("SPELLS_CHANGED") -- a spell learned
        events:RegisterEvent("PLAYER_TALENT_UPDATE") -- talents changed
        events:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED") -- dual spec swap
    end
    ns.Refresh()
    if ns.spell and not fromPet then
        events:UnregisterEvent("SPELLS_CHANGED")
    end
end

SLASH_DISPELGLOW1 = "/dispelglow"
SLASH_DISPELGLOW2 = "/dglow"
SlashCmdList.DISPELGLOW = function()
    local label = "|cff7aa5ffDispelGlow|r: "
    if NATIVE[ns.class] then
        print(label .. "nothing to add, " .. NATIVE[ns.class] .. " already has the game's own glow.")
    elseif ns.spell then
        print(label .. "on, with " .. ns.spell .. ".")
    elseif wanted then
        print(label .. "off until the spell is learned (or, for a warlock, the Felhunter is out).")
    else
        print(label .. "off. This class has no spell that removes Magic from an enemy.")
    end
end
