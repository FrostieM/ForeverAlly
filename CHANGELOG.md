# Changelog

## 1.0.0

First release. Buffs: Priest Fortitude, Divine Spirit; Druid Mark of the Wild; Mage Arcane Intellect; Paladin blessings; optional (off by default): Shadow Protection, Thorns (tanks only by default), Unending Breath, Detect Invisibility. It merges two private addons, Forever Recent Ally Mark and Forever Buff Mark. The client behaviour below was found in game on WoW: Forever (1.60.1), and the addon is built around it:

- `C_NamePlate.GetNamePlates()` leaves friendly plates out, so the `nameplate1`..`nameplate60` tokens are walked instead.
- The game's Recent Allies list (`C_RecentAllies`) misses some players, so the addon keeps its own memory of group members.
- `sourceUnit` of an aura on another player comes back empty, so the blessings you cast with the auto-buff key are remembered for 5 minutes.
- The auto-buff key is bound to a secure button (Key Bindings > AddOns > ForeverAlly) whose macro text the addon rewrites out of combat, only when the pick changes. One run per key press.
- `[@nameplateN]` does nothing, neither in macro text nor as a secure button's unit. Players outside your group are targeted by name and the previous target is restored afterwards.
- `/targetexact` finds a Forever player only by the full "Name Surname". The bare name may target an NPC with that name, and `Name-Surname` never matches.
- The cast text is kept within 255 bytes, like a macro, and non-Latin letters take two. The full name always stays in; the bare name is added only when it fits.
- Buffs are not lowered in rank for low-level targets ("target too low level"). The rank is picked by level, and dropped by one after that error.
- The server answers after the next press may already have moved on, so every answer is tied to its cast (castGUID).
- Spell range checked by spell name answers nothing; the spell ID is used instead.
- Friendly player nameplates are controlled by `nameplateShowFriendlyPlayers`; older clients use `nameplateShowFriends`.
