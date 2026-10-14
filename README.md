# DamageColor

A World of Warcraft: Forever addon that displays school-colored damage with
impact pops above visible enemy nameplates.

Target client: **1.60.1**, build **70374**, dated **October 12, 2026**.
Addon interface: **16001**.

## Required colors

| Damage type | Color |
| --- | --- |
| Auto-attacks | Red on our overlay; native numbers unchanged |
| Physical abilities and bleeds | Red |
| Arcane | Pinkish purple |
| Fire | Orange |
| Shadow | Bluish purple |
| Frost | Light blue |
| Nature | Green |
| Holy | Light yellow |
| Other or unknown | Default yellow |

Mixed-school damage provisionally uses yellow. **Revisit Frostfire at the end.**

## Install and check this build

Copy this folder to `Interface/AddOns/DamageColor` in your Forever installation;
`DamageColor.toc` and `DamageColor.lua` must sit directly inside that folder.
Enable DamageColor in the character-selection AddOns list, then log in or reload.

- `/dc` or `/dc settings`: open the color suite, also available under Settings → AddOns → DamageColor.
- `/dc preview`: show the intended palette using synthetic samples for 10 seconds.
- `/dc on` / `/dc off`: enable or disable live overlay numbers for this session.
- `/dc watch`: collect target combat-event metadata for 20 seconds.
- `/dc stop`: stop collecting early.
- `/dc report`: print the client build, counts, event types, flags, and school masks.

Click a school's button to open the game color picker. Each of the seven schools
has its own color; Other / mixed schools controls the fallback, including
Frostfire. Swatches, hex codes, previews, and active overlay numbers update as you
pick. Cancel restores the color from before opening the picker. Reset colors
restores the original palette. Choices are saved account-wide in `DamageColorDB`
across reloads and logins. The Physical color applies to auto-attacks, physical
skills, and bleeds alike on the overlay; its default is red.

For the compatibility check, attack an isolated enemy with auto-attacks only,
then run `/dc watch` and save `/dc report` after it finishes. Repeat using Heroic
Strike. The diagnostic does not read combat logs or collect damage amounts;
secret metadata is replaced with `<secret>`.

Live damage appears **above visible enemy nameplates**, including mouseover
casts and AoE hits on enemies other than your selected target. All attackers
are included. Known friendly units are excluded using their readable reaction
when the plate appears. Enable enemy nameplates (normally **V**) to see the overlay.
Each number grows quickly to 150% size, settles, and fades after one second,
with only a little upward drift. Numbers capture the nameplate's screen position
at impact and finish there when coordinates are readable. If the client hides
coordinates but exposes the frame, numbers anchor directly above the plate and
clear when that plate is removed to avoid following a reused plate. Switching
targets does not clear numbers on other enemies.
This approximates the native impact effect;
it does not use Blizzard's world-space damage renderer.

If a nameplate is absent, hidden, forbidden, or cannot be anchored,
the overlay skips the hit; there is no screen-center scrolling fallback.
`/dc report` includes live event, shown, and skipped counts plus the latest
display-skip reason; `/dc watch` is not needed for those counters.
Only enemies with accessible visible nameplates have overlay coverage;
periodic hits appear only if the client delivers an event. Up to 64 numbers are
displayed at once; new hits replace the
oldest when full. The overlay is enabled at each login or reload.

Blizzard's native numbers and settings remain unchanged. **Hits may appear
twice:** once in the native display and once in the colored overlay. Native
auto-attacks remain white and native physical skills remain yellow, while both
use Physical (red by default) on our overlay. This is an additive prototype,
not an in-place recolor of Blizzard's numbers.

Unknown nonnegative school masks and mixed schools use the Other color (yellow
by default). Events with secret amounts, secret schools, or unavailable schools
are skipped.

## Compatibility investigation

Forever's available `UNIT_COMBAT` feed reports damage to a unit but does not
identify the attacker or distinguish auto-attacks from physical abilities.
Consequently, a nameplate-based implementation can include other players' hits
and cannot guarantee white auto-attacks alongside red physical skills.
Do not infer damage ownership or school from the player's latest cast; delayed
hits, bleeds, and overlapping attacks make that attribution unreliable.

Player-only damage is preferred; including other attackers is acceptable for an
initial iteration. In-game reports from build 70374 confirmed auto-attacks and
Heroic Strike both report `WOUND`, empty flags, and school `1`. The current
overlay deliberately colors both red, as requested, rather than guessing which
hit is an auto-attack.

References:

- [Forever UNIT_COMBAT API source](https://github.com/Ketho/wow-ui-source-forever/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua)
- [Forever nameplate API source](https://github.com/Ketho/wow-ui-source-forever/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/NamePlateDocumentation.lua)
- [Forever Combat Text author-documented API limitations](https://www.curseforge.com/wow/addons/forever-combat-text)

## Local validation

Run `lua tests/settings_test.lua` from this folder using Lua 5.1. The test uses
mock game frames to check saved colors, cancellation, resets, invalid settings,
live overlay color updates, physical hits, above-plate positioning, pop and
fade animation, secret geometry, mouseover/AoE hits, target-alias duplication,
friendly filtering, and nameplate removal. Settings layout, the color picker,
and nameplate placement still require an in-game check.
