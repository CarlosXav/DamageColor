# DamageColor

Make every hit stand out. DamageColor brings customizable, school-colored damage
numbers to **World of Warcraft: Forever**, with punchy animations, bold critical
hits, and a style you can make your own.

**Damage dealt includes other players' hits on visible enemies.** DamageColor
cannot reliably separate your damage from theirs. You can automatically switch
to Blizzard numbers in instances using the options in **General**.

## Features

- Damage dealt above enemy nameplates, including off-target and area damage.
- Damage taken near your character, with its own size and placement controls.
- Individual colors for each damage school, plus Miss and Resisted messages.
- Five font choices, adjustable text sizes, and larger critical hits.
- Optional colored outlines and soft glows for each damage type.
- Live previews and saved profiles to compare and switch between looks.
- Separate controls for DamageColor and Blizzard damage numbers.

## Installation

1. Place the `DamageColor` folder inside your Forever installation's
   `Interface/AddOns` folder. The addon files should be directly inside
   `Interface/AddOns/DamageColor`, without an extra nested folder.
2. Enable **DamageColor** in the character-selection AddOns list.
3. Enter the game and enable enemy nameplates (normally **V**).
4. Type `/dc` to open settings.

Designed for the Forever client **1.60.1** (build **70374**).

## Make it yours

Open **Settings → AddOns → DamageColor**, or type `/dc`. Expand DamageColor in
the sidebar to find:

| Menu | What you can change |
| --- | --- |
| **General** | Show or hide damage dealt and taken, control Blizzard numbers, and choose when to switch automatically in instances. |
| **Font** | Choose a font and adjust outgoing text size. |
| **Style** | Pick a damage type, then customize its text color, outline, or glow. |
| **Damage Taken** | Adjust incoming text size and position, and preview the placement. |
| **Profiles** | Preview, load, and save your favorite looks. |

Changes apply immediately and are remembered across logins for your account.
Use the previews to check your look without entering combat, including how
critical hits will appear.

### Colors and effects

Start with the school palette below, or change every color to suit your taste.
Auto-attacks, physical abilities, and bleeds share the Physical style.

| Damage type | Default appearance |
| --- | --- |
| Physical | Red |
| Holy | Light yellow |
| Fire | Orange |
| Nature | Green |
| Frost | Light blue |
| Shadow | Bluish purple |
| Arcane | Pinkish purple |
| Frostfire | Light blue with an orange outline |
| Other | Yellow |
| Miss / resist text | White |

Choose **None**, **Outline**, or **Soft glow** for each type, with a separate
edge color and thickness. Frostfire has its own style; changing Fire or Frost
will not change it. Unrecognized damage types use **Other**.

### Profiles

Try **Default**, **Power Glow**, **Power Glow (Lightning)**, **White Outline**,
or **Default (Lightning)**, then save your own variations.

Selecting a profile only previews it. Click **Load profile** to apply it; you
will be asked to confirm before replacing changes you have not saved to a
profile. To keep your current look, enter a name and click **Save profile**.
Saving under an existing custom name updates that profile. **Default** always
keeps the factory settings.

Profiles remember your appearance, damage-taken placement, visibility choices,
and instance options. Your current changes survive reloads even before you save
them to a named profile.

### Switching to Blizzard numbers

In **General**, enable **Disable damage dealt in instances** and/or **Disable
damage taken in instances** to automatically use Blizzard numbers in dungeons,
raids, and battlegrounds. Each direction is independent, and your usual
DamageColor settings return when you leave. Arenas are excluded. Automatic
switching is on by default for damage dealt
and off for damage taken. Existing saved choices are preserved.

Blizzard text must be enabled in the game's settings for it to appear when
switching back. Some changes may wait until combat ends.

## Commands

| Command | What it does |
| --- | --- |
| `/dc` | Open settings. `/dc settings` and `/dc config` also work. |
| `/dc preview` | Show sample damage colors for 10 seconds. |
| `/dc on` | Enable DamageColor for this session, respecting your visibility and instance options. |
| `/dc off` | Disable DamageColor for this session and stop hiding Blizzard numbers. |
| `/dc toggledealt` | Switch damage dealt between DamageColor and Blizzard. |
| `/dc toggletaken` | Switch damage taken between DamageColor and Blizzard. |
| `/dc toggle` | Flip each direction's current selection independently. |

Toggle choices are remembered and can be saved in profiles. `/dc off` lasts
until you enable the addon again or reload.

For troubleshooting, `/dc watch` records a short diagnostic trace, `/dc stop`
ends it early, and `/dc report` prints details useful when reporting a problem.
`/dc meter` shows a snapshot from the game's damage meter when available; some
values may only be readable after combat.

## Things to know

- **Other players' damage is included.** This can make busy encounters crowded;
  the automatic instance options can help.
- **Outgoing numbers need enemy nameplates.** Hits on enemies without accessible
  nameplates may not appear. If Blizzard damage is hidden too, those hits may
  have no visible number.
- **Some hits may be missing**, including certain killing blows, because of
  limits on the combat information available to addons.
- **Showing both displays can duplicate numbers.** Use the Blizzard visibility
  options in General to choose the display you prefer. Healing text is unaffected.
