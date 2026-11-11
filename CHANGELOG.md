# Changelog

## 1.0.2

- Auto buff: after a buff lands, the next press goes to the next player at once. Before, the aura reached the player a moment after the cast, so they still looked unbuffed and the next press cast the same buff on them again ("Spell is not ready yet", or a wasted cast after the global cooldown).
- Auto buff: a press the client refuses before sending a cast ("Out of range") moves that player to the back of the queue, like a failed cast.
- Battlegrounds: the client hides every player's buffs there (yours too), so for you and your group the auto buff now goes by its own casts: a buff it cast is given again when, by its duration, it runs low, or after that player died. Blessing as usual: Kings first, then Wisdom / Might.
- Battlegrounds and other places where the client hides some unit details from addons: a party or raid member is no longer passed over because their GUID, "can assist" or "is a player" comes back hidden.
- Debug log: when nobody is picked, the log says why for each group member (out of range, has all, buffs hidden, can't assist ...), and /fally status says why the target is not suitable.
- Paladin: Kings first for everyone, then Wisdom for mana users and Might for rage and energy users (one blessing of yours per player: Wisdom / Might go to those who already have Kings from another paladin). A blessing order you never changed moves to the new one; one you changed stays.
- Auto buff: "Target is too low level" with no lower rank to try (Kings has a single rank) gives that player the next blessing in the order instead of trying again.
- Auto buff: "A more powerful spell is already active" (another paladin's or priest's higher rank, running low) no longer makes the same press fail again and again: that buff is not offered to that player for 2 minutes, and for a blessing the next kind in the order is given instead.
- Debug log: each pick says the player's class, which blessing order applied and which of your buffs are already on them (any caster), so you can see why that buff was chosen. The log keeps 2000 lines.
- "Skip PvP-flagged players while you are not flagged" is off by default (switched off once on update; switch it on again in `/fally` if you want it). Buffing a flagged player flags you too.
- Your group is buffed even when PvP-flagged while you are not ("Skip PvP-flagged players" now applies only to players outside your group). Buffing a flagged group member flags you too.

## 1.0.1

- Paladin: a separate blessing order for yourself, Kings first by default (then Might, Wisdom). Before, you got the mana users' order (Wisdom first), since a paladin is on mana, which is wrong for a Retribution paladin. Other players keep the mana / rage and energy orders. Set it in `/fally` > Paladin blessings > Blessing order for yourself.

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
