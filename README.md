# DamageColor

A World of Warcraft: Forever addon that displays school-colored damage with
impact pops above visible enemy nameplates.

New numbers try nearby positions beside and above existing hits to avoid overlap,
using the nearest available position and reserving room for settled text sizes
and text edges. Brief pop animations may touch so bursts stay more compact.
Placement uses a bounded search and picks the least crowded position if all
candidates are occupied. When nameplate coordinates are restricted, avoidance
works within each shared nameplate anchor; separate restricted plates may overlap.

Target client: **1.60.1**, build **70374**, dated **October 12, 2026**.
Addon interface: **16001**.

## Required colors

| Damage type | Color |
| --- | --- |
| Auto-attacks | Red on our overlay |
| Physical abilities and bleeds | Red |
| Arcane | Pinkish purple |
| Fire | Orange |
| Shadow | Bluish purple |
| Frost | Light blue |
| Nature | Green |
| Holy | Light yellow |
| Frostfire | Frost light-blue center with Fire orange outline |
| Other or unknown | Default yellow |

Frostfire (school mask 20) has its own color and edge settings. Other mixed schools
use the Other fallback. Frostfire defaults to the original Frost color in the
center and the original Fire color on an outline of thickness 1.5. The previous
inherited fallback defaults migrate once; independently customized styles are
preserved. Frostfire remains independent of changes to Fire, Frost, and Other.

## Install and check this build

Copy this folder to `Interface/AddOns/DamageColor` in your Forever installation;
`DamageColor.toc` and `DamageColor.lua` must sit directly inside that folder.
Enable DamageColor in the character-selection AddOns list, then log in or reload.

- `/dc` or `/dc settings`: open the color suite, also available under Settings → AddOns → DamageColor.
- `/dc preview`: show the intended palette using synthetic samples for 10 seconds.
- `/dc on` / `/dc off`: enable or disable live overlay numbers for this session.
- `/dc watch`: trace combat-event metadata and nameplate removal order for 20 seconds.
- `/dc stop`: stop collecting early.
- `/dc report`: print the client build, counts, event types, flags, and school masks.

Click a school's button to open the game color picker. Each of the seven schools
has its own color, and Frostfire has a separate entry. Other
controls the remaining fallback. Swatches, hex codes, previews, and active overlay numbers update as you
pick. Cancel restores the color from before opening the picker. Reset colors
restores the original palette. Choices are saved account-wide in `DamageColorDB`
across reloads and logins. The Physical color applies to auto-attacks, physical
skills, and bleeds alike on the overlay; its default is red.

The Font dropdown offers Game default, Friz Quadrata, Arial Narrow, Morpheus,
and Skurri, using fonts supplied by the client. Missing font files fall back to
the game's default font. The Text size slider ranges from 12 to 96 UI units
(default 48); critical hits stay twice the selected size. Both controls update
active numbers and the palette preview immediately and are saved account-wide.
Reset font / size restores Game default and 48 without changing colors. Scroll
the settings panel to reach all controls on smaller screens.

Under **Outline and glow**, choose a damage school (or Other for mixed schools),
then choose None, Outline, or Soft glow. Each school saves its own edge color
and thickness / glow radius (1–6 UI units, in quarter-unit steps). None removes
the edge entirely. The default is None: no outline or glow, except Frostfire's
orange outline.
Previous default outlines and white glows are upgraded once; customized
edge styles are preserved. Reset selected
edge restores only that school's edge defaults; text colors are independent.
Changes update active numbers and `/dc preview` immediately, including critical
size, pop, and fade. The edge color picker supports Cancel just like text colors.

The **Number preview** inside the settings menu shows a sample using the school
selected under Outline and glow. It updates immediately with text color, font,
size, and edge changes. Check **Critical hit** to preview twice the normal size.

Colored outlines use offset glyph layers because the native outline flags have
fixed black weights. Soft glow uses three translucent rings to approximate a
blurred halo; it is not a true Gaussian blur. Layers are allocated only as needed
and reused with the damage-number pool (8 for outline, up to 24 for glow).

**Hide Blizzard damage** is checked by default and saved account-wide. It hides
native outgoing damage numbers using `floatingCombatTextCombatDamage_v2`, with
the legacy CVar as a fallback. Unchecking it or using `/dc off` restores the
native setting from before suppression; `/dc on` reapplies the saved preference.
Logout and reload attempt restoration too. If a change is blocked, it retries
on world entry and after combat; `/dc report` includes the suppression status.
Healing text is unaffected. When hiding is enabled, enemies without accessible
nameplates have no damage numbers from either display.

For the compatibility check, attack an isolated enemy with auto-attacks only,
then run `/dc watch` and save `/dc report` after it finishes. Repeat using Heroic
Strike. The diagnostic does not read combat logs or collect damage amounts;
secret metadata is replaced with `<secret>`.

To diagnose a missing killing blow, run `/dc watch`, kill one enemy, then run
`/dc report`. The report includes the last 60 timestamped trace entries: raw
target events, nameplate events, target-alias suppression, displayed hits,
nameplate removal, skip reasons, and listener cleanup. This distinguishes a
missing client event from an event the overlay received but discarded.

The combat-log probe was removed after build 70374 displayed a Blizzard-only
blocked-action warning on event registration. Wrapping that call in `pcall`
does not prevent the client's warning. `/dc watch` now uses only the supported
unit-event diagnostics and never registers combat-log events or reads their
payloads. Missing lethal auto-attacks remain unresolved when neither unit feed
delivers the hit; the visible Blizzard combat log is not proof of addon access.

Live damage appears **above visible enemy nameplates**, including mouseover
casts and AoE hits on enemies other than your selected target. All attackers
are included. Known friendly units are excluded using their readable reaction
when the plate appears. Enable enemy nameplates (normally **V**) to see the overlay.
Each number grows quickly to 150% size, settles, and fades after 1.8 seconds,
with the selected normal text size (48 UI units by default). Hits flagged
`CRITICAL` are twice the normal size throughout the animation (default peak
144 versus 72). The palette preview uses the selected font and text size.
Numbers drift upward slightly and capture the nameplate's screen position
at impact and finish there when coordinates are readable. If the client hides
coordinates but exposes the frame, numbers anchor directly above the plate and
detach to the last readable position when the plate disappears. Switching
targets does not clear numbers on other enemies. Nameplate positions are cached
when they appear and refreshed while readable. If no readable position was ever
available, numbers keep their anchor to the hidden plate and finish fading;
their parent remains the independent overlay. They clear early only if that
same plate is reused for another unit, so old hits cannot follow the new enemy.

Removed nameplates keep their combat listener for another half-second to catch
late killing blows, using the cached position. These hits get the full animation
lifetime, including auto-attacks. A reused nameplate starts a fresh subscription;
its old removal timer cannot disable the new one. A killing blow the client never
delivers, or one with neither a usable position nor an accessible retained
frame anchor, still cannot be displayed.
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

Native damage is hidden by default. If Hide Blizzard damage is unchecked and
the original native display was enabled, **hits may appear twice:** once in
the native display and once in the colored overlay. Native auto-attacks remain
white and native physical skills yellow, while both use Physical (red by
default) on our overlay. The overlay replaces the display when native damage
is hidden; it does not recolor Blizzard's individual numbers.

Unknown nonnegative school masks and mixed schools other than Frostfire use the Other color (yellow
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
