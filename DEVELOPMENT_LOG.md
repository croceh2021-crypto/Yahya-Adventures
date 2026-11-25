# YAHYA ADVENTURES — Development Log

Last updated: 2026-11-25
Engine: Godot 4.4.1
Repository: https://github.com/croceh2021-crypto/Yahya-Adventures
Primary branch: main

## Current requested update

### Single start screen
- Keep exactly one introductory/start screen before gameplay.
- Use the repository image `moh.png` through `res://moh.png` as the full-screen background.
- Keep one primary action: **ابدأ المغامرة**.
- Pressing the button closes the intro and enters the existing game directly; do not insert another menu or character-selection screen.
- The legacy ultimate interface is disabled by the active creature update; the existing pause/completion UI remains gameplay UI, not an extra start menu.
- Intro panel, text and button resize for portrait and landscape phone layouts.

### Creatures and enemies
- The garden spawns 9 enemies, cycling through three enemy types:
  1. Wild dogs.
  2. Fire dragons with animated wings and fire-breath attacks.
  3. Forest monsters with a distinct procedural 3D model, animated arms and ground-shockwave effect.
- Enemy health, speed, damage and rewards are configured by type.
- Enemy health bars display the creature name and use the matching maximum health.

## Files changed for this update
- `Scripts/creature_update.gd`
  - Refined the single `moh.png` intro screen and responsive panel.
  - Added the forest monster model, animation and attack effect.
  - Set enemy-specific stats and names.
- `Scripts/advanced_50_update.gd`
  - Updated monster and dragon health-bar maximums.
- `Scripts/adventure_expansion.gd`
  - Increased initial garden encounters to nine, with three of each type.
- `.github/workflows/android.yml`
  - Preserve and optimize `moh.png` in the APK because the intro scene loads `res://moh.png` directly; do not rename or remove it during export.

## Mobile HUD update (merged)

- Added `Scripts/mobile_controls_update.gd`, inheriting from `Scripts/realism_100_update.gd` so the complete gameplay inheritance chain remains active.
- Updated `Main.tscn` to activate the mobile HUD script.
- The HUD override uses the existing `_exp_layout_hud()` hook from `combat_controls_fix.gd`, calls the inherited implementation, then adjusts health, level, gems, quest text, attack and heal controls for portrait/landscape phone layouts.
- Removed invalid first-draft calls to `_layout_responsive_ui()`, `_layout_garden_ui()` and `_fix_interaction_button_position()`; these methods are not defined in the inherited script chain.
- PR #5 was closed because its branch was three commits behind `main`; its work was reapplied cleanly on the latest mainline in PR #6.
- PR #6 was merged successfully into `main` on 2026-11-25.
- Merge commit: `3136433bd651af4d0d6c098036a7ed278ec808bf`.

## Validation status

- Verified after merge that `Main.tscn` references `res://Scripts/mobile_controls_update.gd`.
- Verified the new script exists on `main` and uses the inherited `_exp_layout_hud()` hook.
- Audited the full script inheritance chain from `mobile_controls_update.gd` through `main.gd`; every parent path exists and no inheritance cycle was found.
- Verified the `moh.png` asset exists in the repository and the main Android workflow preserves it during optimization.
- Static review identified and corrected the invalid layout-hook calls before merge.
- Android APK export and emulator smoke test for the exact merged `main` commit are **not yet confirmed**. Earlier runs tested prior commits only; do not call the merged APK fully validated until the current main build and emulator jobs pass.

## Next steps
1. Confirm Android export and emulator smoke tests for the merged `main` commit.
2. Fix any parser, export or runtime failures discovered by the current build.
3. Record the final APK artifact and test result here.
