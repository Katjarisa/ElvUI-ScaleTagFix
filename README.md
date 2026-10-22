# ElvUI ScaleTagFix

An ElvUI options plugin for **World of Warcraft 3.3.5a (Interface 30300)** and the **ElvUI WotLK 6.09 backport**.

ScaleTagFix is intended to help adapt newer ElvUI profiles to the older WotLK client by providing profile scale-conversion utilities and compatibility tags. It adds its settings to ElvUI's `/ec` options tree rather than opening a separate configuration window.

> **Compatibility note:** This project targets a community backport. Retail ElvUI behavior and APIs are not always available in WoW 3.3.5a. Compatibility tags are best-effort implementations, not a promise of complete retail parity. Test with a backup of your profile.

## Features

- **ElvUI-integrated options:** configure the addon through `/ec` → **Scale & Tag Fix**.
- **Profile scale conversion:** tools for adapting profile dimensions and positions between UI scales.
- **Mover conversion:** optionally adjust mover-related profile data.
- **Size and font adjustments:** optional conversion of recognized size and font values.
- **Retail-style tag compatibility:** adds selected tags when the backport does not already provide them.
- **Unknown-tag scanning:** find tag expressions in profile text settings that this addon does not recognize.
- **Optional unknown-tag stripping:** available for profile strings; scan and back up first.
- **Visibility helpers:** includes a pet-battle visibility compatibility option and pet-bar setting.

Exact behavior depends on the installed ElvUI backport and profile. Review the in-game options and test each operation before using it on your main profile.

## Compatibility tags

The current build includes compatibility implementations for selected tags such as:

- `classcolor`, `classcolor:target`, `reactioncolor`
- `npctitle`, `name:first`, `name:last`, `name:realm`
- `class`, `race`, `level`, `guild`, `realm`, `mouseover`
- `health:percent-with-absorbs`
- `:shortvalue` aliases for selected health, power, and mana tags

Existing tag implementations are not intentionally overwritten. Some tags have reduced behavior on 3.3.5a because the client lacks newer retail APIs. In particular, `health:percent-with-absorbs` falls back to ordinary health percentage when an absorb API is unavailable.

## Installation

1. Back up your ElvUI profile and `WTF/Account/.../SavedVariables` files.
2. Download the ZIP for the desired release, or download this repository as a ZIP.
3. Place the `ElvUI_ScaleTagFix` folder in `Interface/AddOns/`.
4. Ensure ElvUI is installed and enabled.
5. Enable **ElvUI_ScaleTagFix** in the AddOns list and reload the UI.
6. Open `/ec` and select **Scale & Tag Fix** in the options sidebar.

Avoid nested folders such as `Interface/AddOns/ElvUI_ScaleTagFix/ElvUI_ScaleTagFix/core.lua`.

## Recommended workflow for imported profiles

1. Make a backup before converting anything.
2. Import the profile.
3. Open `/ec` → **Scale & Tag Fix** and run the unknown-tag scan.
4. Share any unknown-tag results when requesting compatibility additions.
5. Apply scale conversion only after checking the source and target scale values.
6. Reload and inspect unit frames, nameplates, movers, and fonts.

The scale converter uses heuristic matching of profile keys. Unusual profiles may contain values that need manual review. Do not run conversion repeatedly without checking the result and keeping a backup.

## Troubleshooting

- **Options pages disappear:** disable ScaleTagFix and reload to confirm whether the issue is addon-related. Save the WoW error text (`Errors`/Lua error output) and report the ElvUI backport build.
- **A tag is reported as unknown:** copy the full scan output and include the profile field path shown by the scanner.
- **A tag is recognized but displays incorrectly:** include the exact tag expression, the unit frame where it appears, and whether the unit is a player, NPC, target, boss, etc.
- **Profile dimensions look wrong:** restore the backup and report the source scale, target scale, and affected frame.

## Bug reports

When opening an issue, please include:

- WoW client version (expected: 3.3.5a / 30300)
- Exact ElvUI WotLK backport version/build
- ScaleTagFix version
- Lua error text, if any
- Steps to reproduce
- Unknown-tag scan output, where relevant

Please remove character names, account identifiers, or other personal information from screenshots and profile exports before posting them publicly.

## Development status

This is a community compatibility utility. Test changes in-game on a backed-up profile before relying on them. The addon has not been verified against every ElvUI WotLK fork or every retail profile format.

## License

See [LICENSE](LICENSE).
