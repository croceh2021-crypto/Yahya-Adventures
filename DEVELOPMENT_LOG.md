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

## Existing mobile HUD work
- `Scripts/mobile_controls_update.gd` and its `Main.tscn` link were reapplied on top of the latest creature update in PR #5, branch `fix/mobile-hud-after-creatures-2026-11-25`.
- PR #5 is open and awaits final Android emulator validation; its HUD change is not active on `main` until merged.
- Code review found that the first HUD draft called `_layout_responsive_ui()`, `_layout_garden_ui()` and `_fix_interaction_button_position()`, which are not defined in the inherited script chain. Those calls were removed. The update now overrides the real inherited `_exp_layout_hud()` hook from `combat_controls_fix.gd`, calls its parent implementation, and then applies the compact mobile layout.
- Superseded PR #4 was closed to avoid merging an outdated branch.

## Validation status
- PR #5 workflow run `45692938270`: Android APK export **passed**; Android emulator smoke test was **queued** at the last check.
- The mobile HUD hook correction was committed as `bf596210d9403999981642bb6a5157040526ec04`; its updated workflow run must complete before merge.
- Do not describe the APK as fully tested or ready until both export and emulator smoke-test jobs complete successfully.
- Workflow runs started for the three commits:
  - `90f6816b7541e13cde25cc0fd389b19f827ec823`
  - `158d8343820ce7e151ffea5342bec7846d5b8fae`
  - `0aaef16b2d13d31b94b0907579b4bfd015b74ea4`

## Next steps
1. Confirm the updated PR build and Android emulator smoke test both pass.
2. Fix any parser, export or runtime failures before distributing an APK.
3. Merge PR #5 only after the checks pass, then verify the resulting `main` commit and workflow.
4. Keep this log updated after each verified change and test.
