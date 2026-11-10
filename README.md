<p align="center"><img src="media/logo.png" width="160" alt="ForeverAlly logo"></p>

# ForeverAlly

You run through a busy town, and half the people around you could use your buff. Which half? And that warrior by the mailbox: didn't you tank a dungeon together last week?

**ForeverAlly** answers both, right on the nameplates of the players around you. It is built and tested for **WoW: Forever**.

<p align="center">
  <img src="media/ally-and-buff.jpg" height="300" alt="Recent ally icon before the name, missing buff after it">
  <img src="media/blessing.jpg" height="300" alt="The blessing this player still needs">
  <img src="media/missing-buff.jpg" height="300" alt="A missing buff on a nearby player">
</p>

## Recent allies

Anyone you've been in a group with gets a small icon by their name and a line in their tooltip: "Grouped with you before". The game's own Recent Allies list misses some people (friends, for example), so ForeverAlly keeps its own memory. You can also mark or unmark your target by hand with `/ally add` and `/ally del`.

## Missing buffs

Out of combat, next to each friendly player's name you see the icon of every one of *your* class buffs they don't have.

- **Priest:** Fortitude, Divine Spirit
- **Druid:** Mark of the Wild
- **Mage:** Arcane Intellect
- **Paladin:** the best blessing that player can still get
- **Optional, off by default:** Shadow Protection, Thorns (tanks only or everyone), Unending Breath, Detect Invisibility

A buff with less than 30% of its time left counts as missing, so you can renew it early. The threshold is adjustable.

## One-key auto buff

Press a key, and the next player who needs a buff gets it: you first, then your group, then everyone around. It is one cast per key press, out of combat only. You press the key every time, so it is not a bot.

- **Right rank for the level.** Forever doesn't pick the rank by itself, so the addon does, and low-level players don't get "target too low level".
- **Smart blessings.** For paladins it picks the best blessing each player can still get and takes other paladins' blessings into account. You set the order separately for mana users and for rage and energy users. Tanks get no Salvation by default.
- **Never stuck.** Someone out of sight goes to the back of the queue for a few seconds.

## Install

- **CurseForge:** [ForeverAlly](https://www.curseforge.com/wow/addons/foreverally), or search for ForeverAlly in the CurseForge app.
- **By hand:** download the zip from [Releases](../../releases), unpack it into `World of Warcraft\_forever_\Interface\AddOns` so that the folder is called `ForeverAlly`.

## Getting started

1. Turn on friendly player nameplates. If they are off, the addon tells you and can switch them on.
2. Set your auto-buff key in `/fally`, or in Key Bindings > AddOns > ForeverAlly.
3. Walk into a crowd and press it.

Every part can be turned off on the options page. There you also choose icon sizes, which buffs to track and who to buff: yourself, your group or everyone.

## Works with

- No UI addons at all.
- UI suites that keep Blizzard's nameplates, such as EllesmereUI.
- Nameplate replacements like Plater: the icons sit above the plate.

## Commands

- `/fally`: options
- `/fally status`: what the addon thinks of your target, and what the next key press will cast
- `/fally log on|off|show|clear`: troubleshooting log
- `/ally add`, `/ally del`: mark or unmark a recent ally

## Languages

English, Р СѓСЃСЃРєРёР№, Deutsch, FranГ§ais, EspaГ±ol, PortuguГЄs (Brasil), Italiano. Spell names come from the game in your client's language. Translation fixes are welcome: open an issue or a pull request against `Locales.lua`.

## Notes for developers

The Forever client behaves differently from retail and Classic in several places (friendly nameplates, `/targetexact`, ranks, aura sources). [CHANGELOG.md](CHANGELOG.md) lists what was found and how the addon works around it.

## License

MIT, see [LICENSE](LICENSE).

---

## РџРѕ-СЂСѓСЃСЃРєРё

Р‘РµР¶РёС€СЊ С‡РµСЂРµР· РіРѕСЂРѕРґ, РІРѕРєСЂСѓРі С‚РѕР»РїР°, Рё РїРѕР»РѕРІРёРЅРµ РЅРµ РїРѕРјРµС€Р°Р» Р±С‹ С‚РІРѕР№ Р±Р°С„С„. РўРѕР»СЊРєРѕ РєРѕРјСѓ РёРјРµРЅРЅРѕ? Рђ РІРѕРЅ С‚РѕС‚ РІРѕРёРЅ Сѓ РїРѕС‡С‚С‹: РЅРµ СЃ РЅРёРј Р»Рё С‚С‹ РЅР° РїСЂРѕС€Р»РѕР№ РЅРµРґРµР»Рµ С…РѕРґРёР» РІ РїРѕРґР·РµРјРµР»СЊРµ?

**ForeverAlly** РїРѕРєР°Р·С‹РІР°РµС‚ СЌС‚Рѕ РїСЂСЏРјРѕ РЅР° С‚Р°Р±Р»РёС‡РєР°С… РёРіСЂРѕРєРѕРІ. РЎРґРµР»Р°РЅ Рё РїСЂРѕРІРµСЂРµРЅ РЅР° **WoW: Forever**.

- **РќРµРґР°РІРЅРёРµ СЃРѕСЋР·РЅРёРєРё.** РЈ С‚РµС…, СЃ РєРµРј С‚С‹ Р±С‹Р» РІ РіСЂСѓРїРїРµ, СЂСЏРґРѕРј СЃ РёРјРµРЅРµРј Р·РЅР°С‡РѕРє, Р° РІ РїРѕРґСЃРєР°Р·РєРµ СЃС‚СЂРѕРєР° В«Р‘С‹Р»Рё РІ РѕРґРЅРѕР№ РіСЂСѓРїРїРµВ». РРіСЂРѕРІРѕР№ СЃРїРёСЃРѕРє РЅРµРґР°РІРЅРёС… СЃРѕСЋР·РЅРёРєРѕРІ РїСЂРѕРїСѓСЃРєР°РµС‚ Р»СЋРґРµР№, РЅР°РїСЂРёРјРµСЂ РґСЂСѓР·РµР№, РїРѕСЌС‚РѕРјСѓ Р°РґРґРѕРЅ РїРѕРјРЅРёС‚ РёС… СЃР°Рј. РћС‚РјРµС‚РёС‚СЊ С†РµР»СЊ РІСЂСѓС‡РЅСѓСЋ: `/ally add`, СЃРЅСЏС‚СЊ РѕС‚РјРµС‚РєСѓ: `/ally del`.
- **РљРѕРјСѓ С‡РµРіРѕ РЅРµ С…РІР°С‚Р°РµС‚.** Р’РЅРµ Р±РѕСЏ РІРѕР·Р»Рµ РёРјРµРЅРё РґСЂСѓР¶РµСЃС‚РІРµРЅРЅРѕРіРѕ РёРіСЂРѕРєР° РІРёРґРЅС‹ Р·РЅР°С‡РєРё С‚РІРѕРёС… РєР»Р°СЃСЃРѕРІС‹С… Р±Р°С„С„РѕРІ, РєРѕС‚РѕСЂС‹С… Сѓ РЅРµРіРѕ РЅРµС‚. Р–СЂРµС†, РґСЂСѓРёРґ, РјР°Рі Рё РїР°Р»Р°РґРёРЅ. Р‘Р°С„С„, Сѓ РєРѕС‚РѕСЂРѕРіРѕ РѕСЃС‚Р°Р»РѕСЃСЊ РјРµРЅСЊС€Рµ 30% РІСЂРµРјРµРЅРё, С‚РѕР¶Рµ СЃС‡РёС‚Р°РµС‚СЃСЏ РЅРµРґРѕСЃС‚Р°СЋС‰РёРј.
- **РђРІС‚РѕР±Р°С„С„ РѕРґРЅРѕР№ РєР»Р°РІРёС€РµР№.** РљР°Р¶РґРѕРµ РЅР°Р¶Р°С‚РёРµ Р±Р°С„С„Р°РµС‚ СЃР»РµРґСѓСЋС‰РµРіРѕ, РєРѕРјСѓ РЅСѓР¶РЅРѕ: СЃРЅР°С‡Р°Р»Р° С‚РµР±СЏ, РїРѕС‚РѕРј РіСЂСѓРїРїСѓ, РїРѕС‚РѕРј РІСЃРµС… РІРѕРєСЂСѓРі. РћРґРЅРѕ РЅР°Р¶Р°С‚РёРµ, РѕРґРЅРѕ Р·Р°РєР»РёРЅР°РЅРёРµ, С‚РѕР»СЊРєРѕ РІРЅРµ Р±РѕСЏ. Р­С‚Рѕ РЅРµ Р±РѕС‚. Р Р°РЅРі РїРѕРґР±РёСЂР°РµС‚СЃСЏ РїРѕ СѓСЂРѕРІРЅСЋ С†РµР»Рё, Р° РїР°Р»Р°РґРёРЅ РІРµС€Р°РµС‚ РєР°Р¶РґРѕРјСѓ Р»СѓС‡С€РµРµ Р±Р»Р°РіРѕСЃР»РѕРІРµРЅРёРµ РёР· С‚РµС…, С‡С‚Рѕ РёРіСЂРѕРє РµС‰С‘ РјРѕР¶РµС‚ РїРѕР»СѓС‡РёС‚СЊ, СЃ СѓС‡С‘С‚РѕРј РґСЂСѓРіРёС… РїР°Р»Р°РґРёРЅРѕРІ.

**РЎ С‡РµРіРѕ РЅР°С‡Р°С‚СЊ:** РІРєР»СЋС‡Рё С‚Р°Р±Р»РёС‡РєРё РґСЂСѓР¶РµСЃС‚РІРµРЅРЅС‹С… РёРіСЂРѕРєРѕРІ (Р°РґРґРѕРЅ РїРѕРґСЃРєР°Р¶РµС‚) Рё РЅР°Р·РЅР°С‡СЊ РєР»Р°РІРёС€Сѓ РІ `/fally`.

Р Р°Р±РѕС‚Р°РµС‚ Р±РµР· РґСЂСѓРіРёС… Р°РґРґРѕРЅРѕРІ Рё СЃ РёРЅС‚РµСЂС„РµР№СЃР°РјРё РЅР° СЃС‚Р°РЅРґР°СЂС‚РЅС‹С… С‚Р°Р±Р»РёС‡РєР°С… (EllesmereUI). РЎ Plater Р·РЅР°С‡РєРё СЃС‚РѕСЏС‚ РЅР°Рґ С‚Р°Р±Р»РёС‡РєРѕР№. Р’СЃРµ РЅР°СЃС‚СЂРѕР№РєРё РЅР° СЂСѓСЃСЃРєРѕРј.
