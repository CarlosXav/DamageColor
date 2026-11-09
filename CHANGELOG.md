# Changelog

## 1.1.3

- Display Dodge messages for damage dealt and damage taken using the shared
  Miss / resist / dodge text style.
- Update the style selection and profile preview labels to include dodge.

## 1.1.2

- Add All damage / Target only selection beneath the outgoing damage checkbox
  in General. The dropdown is disabled when outgoing numbers are turned off.
- Save the outgoing damage selection account-wide and in profiles. All damage
  remains the default; Target only includes all attackers hitting your target.

## 1.1.1

- Restore damage numbers on Forever build 70790 when the client restricts damage
  amounts, including support for colored outlines and glows.
- Use the Other style when a damage school is unavailable.

## 1.1.0

- Update the documented Forever client target to 1.60.1 (build 70790).

## 1.0.1

- Automatically switch outgoing damage to Blizzard numbers in dungeons, raids,
  and battlegrounds by default for new settings. Existing saved choices are
  preserved; automatic switching for incoming damage remains off by default.
- Configure CurseForge release packaging with the DamageColor addon folder,
  excluding development files.
