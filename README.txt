ElvUI ScaleTagFix 0.7.1
=======================
Target: World of Warcraft 3.3.5a (Interface 30300), ElvUI WotLK 6.09

INSTALL
1. Back up your existing ElvUI_ScaleTagFix folder and SavedVariables.
2. Remove the old ElvUI_ScaleTagFix folder.
3. Extract this folder into Interface/AddOns.
4. Enable ElvUI and ElvUI_ScaleTagFix, then /reload.
5. Open /ec and choose Scale & Tag Fix in the ElvUI options list.

NOTES
- This is an ElvUI options plugin; it does not create a standalone window.
- Compatibility tags are enabled by default on a fresh install.
- Existing tags supplied by your ElvUI backport are not overwritten.
- Tag metadata is added from the ElvUI plugin options callback to avoid
  modifying the WotLK options tree during addon initialization.
- Added compatibility tags: classcolor, classcolor:target, reactioncolor,
  npctitle, name:first, name:last, class, race, level, guild, realm,
  name:realm, mouseover, health:percent-with-absorbs, plus :shortvalue aliases for existing health/power/mana tags.
- This is a practical compatibility set, not a complete implementation of
  every tag introduced by every later retail ElvUI release. Use Scan for
  unknown tags after importing a profile; share that output to add more
  tags safely based on the actual profile and backport API.
- Always back up your profile before Apply & Reload. The size converter uses
  heuristic key matching and may need tuning for unusual profile fields.
- Use Scan before enabling Remove unknown tags; removal edits profile strings.

- Version 0.7.1 adds the two tags reported by the scan:
  [mouseover] and [health:percent-with-absorbs].
- On the 3.3.5 client, absorb-aware health uses the absorb API only if
  available; otherwise it falls back to regular health percentage.
