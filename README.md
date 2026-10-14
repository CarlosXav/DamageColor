# DamageColor

A World of Warcraft: Forever addon that displays magic damage in school colors.

Target client: **1.60.1**, build **70374**, dated **October 12, 2026**.
Addon interface: **16001**.

## Required colors

| Damage type | Color |
| --- | --- |
| Auto-attacks | White (unchanged) |
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
- `/dc on` / `/dc off`: enable or disable live magic numbers for this session.
- `/dc watch`: collect target combat-event metadata for 20 seconds.
- `/dc stop`: stop collecting early.
- `/dc report`: print the client build, counts, event types, flags, and school masks.

Click a school's button to open the game color picker. Each of the seven schools
has its own color; Other / mixed schools controls the fallback, including
Frostfire. Swatches, hex codes, previews, and active magic numbers update as you
pick. Cancel restores the color from before opening the picker. Reset colors
restores the original palette. Choices are saved account-wide in `DamageColorDB`
across reloads and logins. Auto-attacks stay white; the physical-skill setting
affects only the preview until live physical skills can be identified.

For the compatibility check, attack an isolated enemy with auto-attacks only,
then run `/dc watch` and save `/dc report` after it finishes. Repeat using Heroic
Strike. The diagnostic does not read combat logs or collect damage amounts;
secret metadata is replaced with `<secret>`.

Live magic damage appears in a small rising, fading stream above screen center.
It uses damage events on your **current target**, including other attackers.
Off-target damage is not displayed; periodic hits appear only if the client
delivers an event. Up to 24 numbers are displayed at once; new hits replace the
oldest when full. The overlay is enabled at each login or reload.

Blizzard's native numbers and settings remain unchanged. Auto-attacks stay
white; physical skills such as Heroic Strike retain their native yellow for now.
**Magic hits may appear twice:** once in the native display and once in the
colored overlay. Native text cannot be selectively suppressed by this addon
while preserving physical hits. This is an additive prototype, not an in-place
recolor of Blizzard's numbers.

Unknown positive school masks and mixed schools use yellow. Events with secret
amounts, secret schools, or unavailable schools are skipped. Physical-school
events do not create overlay numbers. The preview includes the planned red
physical-skill color, which is not active in live combat.

## Compatibility investigation

Forever's available `UNIT_COMBAT` feed reports damage to a unit but does not
identify the attacker or distinguish auto-attacks from physical abilities.
Consequently, a target-based implementation can include other players' hits
and cannot guarantee white auto-attacks alongside red physical skills.
Do not infer damage ownership or school from the player's latest cast; delayed
hits, bleeds, and overlapping attacks make that attribution unreliable.

Player-only damage is preferred; including other attackers is acceptable for an
initial iteration. Auto-attacks must still remain white, while physical skills
such as Heroic Strike should eventually become red. In-game reports from build
70374 confirmed both report `WOUND`, empty flags, and school `1`. Physical
recoloring is therefore deferred; native physical text remains unchanged.

References:

- [Forever UNIT_COMBAT API source](https://github.com/Ketho/wow-ui-source-forever/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua)
- [Forever Combat Text author-documented API limitations](https://www.curseforge.com/wow/addons/forever-combat-text)

## Local validation

Run `lua tests/settings_test.lua` from this folder using Lua 5.1. The test uses
mock game frames to check saved colors, cancellation, resets, invalid settings,
and live overlay color updates. Settings layout and the actual color picker
still require an in-game check.
