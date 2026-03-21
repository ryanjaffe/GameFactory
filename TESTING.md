# Testing

This document is a manual smoke-test checklist for Godot Game Factory.

## Basic Build

- Run `swift build`.
- Confirm the app compiles successfully.

## Blank Template

- Create a project with the `Blank` template.
- Confirm the project folder is created.
- Confirm `README.md`, `.gitignore`, `AGENTS.md`, `run_validation.sh`, and `project.godot` exist.
- Confirm `tests/validation_notes.md` exists.
- Confirm `run_validation.sh` is executable.

## 2D Platformer Starter

- Create a project with `2D Platformer Starter`.
- Confirm:
  - `scenes/platformer_playground.tscn`
  - `scripts/platformer_player.gd`
  - `tests/platformer_starter_notes.md`
- Confirm the summary and prompt pack reference the platformer starter.

## Top-Down Starter

- Create a project with `Top-Down Starter`.
- Confirm:
  - `scenes/top_down_playground.tscn`
  - `scripts/top_down_player.gd`
  - `tests/top_down_starter_notes.md`
- Confirm the summary and prompt pack reference the top-down starter.

## 3D Starter

- Create a project with `3D Starter`.
- Confirm:
  - `scenes/starter_3d_playground.tscn`
  - `scripts/player_controller_3d.gd`
  - `tests/starter_3d_notes.md`
- Confirm the summary and prompt pack reference the 3D starter.

## Dialogue / Narrative Starter

- Create a project with `Dialogue / Narrative Starter`.
- Confirm:
  - `scenes/dialogue_playground.tscn`
  - `scripts/dialogue_controller.gd`
  - `tests/dialogue_outline.txt`
  - `tests/dialogue_starter_notes.md`
- Confirm the summary and prompt pack reference the dialogue starter.

## Dry Run Vs Real Create

- Run Dry Run with a valid project configuration.
- Confirm no project folder is created.
- Confirm preview logs show the final path, file list, and integration plan.
- Run a real create with the same configuration.
- Confirm the project is actually created.

## Git Init

- Create a real project on a machine with `git` available.
- Confirm a `.git` directory exists.
- Confirm `git log --oneline -1` shows `Initial project scaffold`.
- Confirm the project remains on disk even if Git setup fails.

## Optional GitHub Path

- Create a real project with a GitHub username set.
- If `gh` is unavailable, confirm creation still succeeds and the log shows a clear skip message.
- If `gh` is installed but not authenticated, confirm creation still succeeds and the log suggests `gh auth login`.
- If `gh` is installed and authenticated, confirm the repo create/push path works as expected.

## Presets

- Save a preset from the current form.
- Confirm it appears in the preset picker.
- Apply the preset and confirm the form updates.
- Confirm applying a preset does not create a project.
- Save another preset with the same name and confirm the app does not overwrite silently.
- Delete a preset and confirm it is removed.
- Relaunch the app and confirm presets persist.

## Recent Projects

- Create a real project and confirm it appears in Recent Projects.
- Create another real project and confirm the list is ordered with newest first.
- Recreate the same path and confirm the recent entry updates instead of duplicating.
- Relaunch the app and confirm recent projects persist.

## Open In Codex Handoff

- Create a real project.
- Use `Open in Codex` from the last-created project area.
- Confirm the starter prompt is copied.
- Confirm Terminal opens to the project folder.
- Confirm the app shows a short Codex handoff message.
- Repeat from a Recent Projects row and confirm the same behavior.

## Folder Picker

- Use `Choose Folder` next to the base directory field.
- Confirm selecting a folder updates the base directory field.
- Confirm cancelling leaves the field unchanged.
- Relaunch the app and confirm the selected directory persists through normal settings persistence.

## Generated Workflow Files

- Open the generated `AGENTS.md` and confirm it references the selected template.
- Open `run_validation.sh` and confirm it references the selected template and starter scene where applicable.
- Run `./run_validation.sh` and confirm it writes to `artifacts/validation.log`.
- Confirm `README.md` includes template-specific notes.
