# Godot Game Factory

Godot Game Factory is a local macOS app for creating, inspecting, and maintaining Codex-friendly Godot projects.

It keeps the common setup and handoff work in one place:
- scaffold a new project
- initialize Git
- optionally create a GitHub repo through `gh`
- generate and edit workflow files
- inspect and audit existing projects
- prepare prompt, validation, and handoff context for Codex

The app is local-first, non-destructive by default, and biased toward small, inspectable workflows.

## Supported Templates

- Blank
- 2D Platformer Starter
- Top-Down Starter
- 3D Starter
- Dialogue / Narrative Starter

Templates stay intentionally lightweight. They add small starter scenes, scripts, notes, and workflow guidance rather than full gameplay systems.

## Current V3 Capabilities

- new project form with project name, base directory, GitHub username, repo visibility, template, and optional Godot path
- dry run / preview mode before writing files
- safe folder collision handling using suffixed project folders
- local scaffold generation with workflow files and lightweight template content
- local Git initialization with an initial commit
- optional GitHub repo creation through `gh`
- project summary with Git and GitHub status
- copyable project summary and file tree
- recent projects with persistence and dedupe
- reusable named presets
- Finder-based base-directory picker
- Open in Codex handoff
- Open in Godot launch
- project inspector for existing folders
- lightweight project audit
- built-in workflow file editor for `AGENTS.md`, `README.md`, and `run_validation.sh`
- workflow file repair / restore-default actions
- per-project workflow settings in `gamefactory.workflow.json`
- manual asset import into `art/`
- built-in asset starter packs
- asset-aware Codex prompt generation
- handoff bundle export
- visible log panel for automation steps and failures

## Workflow Files And Handoff

Generated projects include:
- `AGENTS.md`
- `README.md`
- `run_validation.sh`
- `.gitignore`
- `project.godot`

Game Factory can then help you keep those files usable:
- open and edit `AGENTS.md`, `README.md`, and `run_validation.sh`
- restore default versions of those files when they are missing or need repair
- store small per-project workflow settings
- generate a template-aware prompt pack
- export a concise handoff bundle with summary, file tree, audit state, workflow settings, asset context, and starter prompt

## Project Inspector And Audit

The app is not limited to projects created in the current session.

You can open an existing project folder and inspect:
- whether `project.godot`, `AGENTS.md`, `README.md`, and `run_validation.sh` exist
- whether `.git` exists
- whether an `origin` remote is detectable
- whether key directories such as `scenes/`, `scripts/`, `art/`, `tests/`, and `artifacts/` exist
- which template the project appears to use, when detectable

You can also run a lightweight audit that checks:
- core project files
- workflow file presence and `run_validation.sh` executability
- expected directory structure
- Git and origin status
- template-specific starter files when the template is known

## Assets

Game Factory supports lightweight local asset workflows:
- import one or more files into `art/`
- create `art/` safely if it is missing
- avoid silent overwrites with suffixed filenames
- apply small built-in starter packs
- include asset summaries in prompt generation and handoff bundles

Built-in starter packs are intentionally small and local. They use simple placeholder files instead of downloads or large bundled assets.

## Open In Codex

Open in Codex is a lightweight handoff flow.

It currently:
- copies the best starter prompt for the active project
- uses the template and project workflow settings
- includes asset context when available
- opens the project folder in Terminal
- shows a short next-step message in the app

It does not directly launch a separate Codex app workflow.

## Open In Godot

Open in Godot launches the active project using this resolution order:
1. project-local `godotPathOverride` from `gamefactory.workflow.json`
2. app-level Godot path setting
3. fallback `open -a Godot`

If Godot cannot be found, the app fails gracefully and reports a short message in the log panel.

## Typical Workflow

1. Enter a project name and base directory.
2. Optionally choose a template, GitHub username, repo visibility, and app-level Godot path.
3. Optionally use Dry Run or Preview Plan to inspect the final path, file list, and Git/GitHub plan first.
4. Create the project scaffold.
5. Review the summary, logs, workflow files, and prompt pack.
6. Optionally edit workflow files or project workflow settings.
7. Optionally import assets or apply a starter pack.
8. Use Open in Codex, Open in Godot, or Copy Handoff Bundle to continue work.

## Recent Projects And Presets

Recent Projects:
- store real project creations across launches
- stay bounded and deduped by project path
- provide quick actions such as Open in Codex, Open in Godot, Copy Path, and Open in Finder

Presets:
- save named creation defaults for base directory, GitHub username, repo visibility, and template
- apply values back into the form without creating a project
- persist across launches

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

Some features depend on local tools:

- `git` for repository initialization and repo inspection
- `gh` for optional GitHub repo creation
- `godot` for project launch and fuller validation workflows

The app is expected to handle missing tools gracefully.

## Known Limits

- The app currently targets macOS.
- Templates and starter packs are intentionally small, not full gameplay or asset systems.
- `run_validation.sh` is a lightweight starter script, not a full automation pipeline.
- GitHub setup depends on `gh` being installed and authenticated.
- Open in Codex is a composed local handoff flow, not a direct Codex launcher.
- Project inspection and template detection are lightweight and can fall back to `Unknown`.
- Workflow file repair restores default generated versions; it does not merge user edits.

## Testing

See [TESTING.md](/Users/ryan/Documents/CODEX/GameFactory/TESTING.md) for the manual smoke-test checklist.
