# Changelog

## 1.0.0 (not released yet)

### Changed

- Glows only when your character has a spell that removes Magic from an enemy: Purge (shaman), Dispel Magic and Mass Dispel (priest), Tranquilizing Shot (hunter), Shield Slam (warrior), and Devour Magic while the Felhunter is out (warlock). Before, every class saw the glow.
- A mage is left to the game's own Spellsteal glow, which already marks exactly the buffs that can be stolen.
- Looks for the spell again after a respec or a dual spec swap.
- Draws the glow after Blizzard redraws the target and focus buffs, instead of replacing the game's `UnitAura` and `UnitBuff`. Other addons and protected parts of the interface are no longer affected.
- Classes that cannot remove Magic hook nothing and listen to no events.

### Added

- `/dispelglow` (or `/dglow`) says whether the glow is on, and with which spell.
- Tests (busted) and luacheck, run in CI on every pull request.

### Removed

- Resetting the Details meter on logout. It had nothing to do with buffs.

## First version

The addon as it ran in the game folder under the name `a`: every Magic buff on an enemy was marked as stealable, so the target frame showed the Spellsteal glow for every class.
