# Godot Game Factory

Godot Game Factory is a local macOS app for creating Codex-friendly Godot project scaffolds.

It handles the repetitive setup around a new project:
- folder structure
- starter files
- Git setup
- optional GitHub setup through `gh`
- validation workflow files
- Codex handoff helpers

The app is local-first and designed to keep setup visible, repeatable, and non-destructive.

## Current Features

- new project form with project name, base directory, GitHub username, repo visibility, and template
- dry run / preview mode before writing files
- non-destructive folder collision handling using suffixed project folders
- local scaffold generation with starter files and workflow files
- local Git initialization with initial commit
- optional GitHub repo creation through `gh`
- visible log panel
- post-create project summary with Git and GitHub status
- copyable summary and file tree
- template-aware Codex prompt pack
- Open in Codex handoff flow
- recent projects with persistence
- reusable presets
- Finder-based base directory picker

## Supported Templates

- Blank
- 2D Platformer Starter
- Top-Down Starter
- 3D Starter
- Dialogue / Narrative Starter

Templates stay intentionally lightweight. They add small starter scenes, scripts, notes, and workflow guidance rather than full gameplay systems.

## Normal Workflow

1. Enter a project name and base directory.
2. Optionally choose a template, GitHub username, and repo visibility.
3. Optionally use Dry Run or Preview Plan to inspect the outcome first.
4. Create the project scaffold.
5. Review the generated summary, workflow files, and logs.
6. Use post-create actions or Open in Codex to continue work.

## Dry Run

Dry Run validates the form, computes the final target path, applies collision handling, and shows the folders, files, Git step, and GitHub step that would be used.

Dry Run does not:
- create files or folders
- initialize Git
- call `gh`
- update post-create summary state

## Open in Codex

Open in Codex is a lightweight handoff action.

It currently:
- copies the best starter prompt for the selected project and template
- opens the project folder in Terminal
- shows a short next-step handoff message in the app

It does not directly launch a separate Codex app workflow.

## Recent Projects And Presets

Recent Projects:
- stores recent real project creations across launches
- keeps the list bounded and deduped by project path
- provides quick actions like Copy Path, Open in Finder, and Open in Codex

Presets:
- save named creation defaults for base directory, GitHub username, repo visibility, and template
- apply values back into the form without creating a project
- persist across launches

## Generated Workflow Files

Generated projects include:
- `AGENTS.md`
- `run_validation.sh`
- `README.md`
- `.gitignore`
- `project.godot`

Template starters may also add scenes, scripts, and notes files under `scenes/`, `scripts/`, and `tests/`.

## Local Run

From the repository root:

```bash
swift run
```

Build only:

```bash
swift build
```

## External Tools

Some app features depend on local tools:

- `git` for repository initialization
- `gh` for optional GitHub repo creation
- `godot` for fuller validation workflows inside generated projects

The app is expected to handle missing tools gracefully.

## Known Limits

- The app currently targets macOS.
- Templates are intentionally small and not full gameplay frameworks.
- `run_validation.sh` is a starter validation script, not a full automation pipeline.
- GitHub setup depends on `gh` being installed and authenticated.
- Open in Codex is a composed handoff flow, not a direct Codex launcher integration.

## Testing

See [TESTING.md](/Users/ryan/Documents/CODEX/GameFactory/TESTING.md) for a manual smoke-test checklist.
