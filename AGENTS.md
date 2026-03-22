Telsh;dlgh;ldsfj;ljjl;sjd;lfjlkjdssdkjghh;ldshf;kljl;ksdfsdafsdafsdasdfdsfagwevsdf;lkjs;dljg;ljsdjfdshfljkkTTjds;lkjtkjekljr;jweljhlhgdsljl;kfjklsdjTsdfj;lsdjlfkjl;ksdjghldfhlkjsdlkjfdsj;ljasd;lfj;ldd## Purpose

This repository is for building and maintaining **Godot Game Factory**, a local macOS app that creates Codex-friendly Godot project scaffolds.

The app should help a user:
- create new Godot projects quickly
- make setup repeatable
- initialize Git
- optionally create GitHub repos
- generate Codex workflow files
- generate validation files and starter templates

Agents working in this repo must optimize for:
- reliability
- repeatability
- clarity
- safe local execution
- low setup friction

---

## Product Goal

Build a local GUI app that acts as a **project factory** for Godot game development.

Every generated project should be:
- easy to create
- easy to inspect
- ready for Codex
- ready for Git
- optionally ready for GitHub
- structured consistently

The app should reduce manual terminal work and eliminate ad hoc setup.

---

## Primary Platform

- Target OS: macOS
- Primary runtime: local desktop app
- Preferred implementation: simple, maintainable, local-first stack
- Default bias: prefer the smallest working solution over a more complex architecture

If the stack has already been chosen in the repo, follow the existing stack unless explicitly instructed otherwise.

---

## Core Principles

- Prefer working software over ambitious architecture
- Prefer simple flows over clever abstractions
- Prefer transparent automation over hidden behavior
- Prefer deterministic generation over “magic”
- Prefer explicit logs and status over silent failure

---

## Hard Rules

- DO NOT delete user projects
- DO NOT overwrite existing project folders without explicit confirmation logic
- DO NOT perform destructive file operations by default
- DO NOT assume `git`, `gh`, or `godot` exist without checking
- DO NOT hardcode machine-specific paths except where clearly configured
- DO NOT silently swallow subprocess failures
- DO NOT add unnecessary dependencies
- DO NOT introduce cloud dependencies for core functionality
- DO NOT overengineer v1

---

## Definition of Done

A task is only complete if:

1. The feature works locally
2. The behavior is visible and inspectable
3. Errors are handled clearly
4. Existing functionality is not broken
5. The implementation is consistent with the current architecture
6. Any user-facing automation is reflected in logs or status output

---

## Scope of the App

The app may include:

- New Project Wizard
- Project scaffolding
- Git initialization
- GitHub repo creation through `gh`
- AGENTS.md generation
- validation script generation
- starter Godot test/playground files
- prompt generation for Codex
- settings persistence
- dry run mode
- safe mode

The app should NOT drift into becoming a full game engine, editor, or launcher platform unless explicitly requested.

---

## Preferred Development Flow

For every task:

1. Understand the smallest useful change
2. Identify the minimal files involved
3. Implement the change
4. Run local validation
5. Report exactly what changed
6. Note any uncertainty or follow-up work

Agents must avoid broad, unrelated refactors.

---

## Task Size Guidance

Good tasks:
- add a field to the New Project form
- generate AGENTS.md from a template
- add Git initialization service
- add dry run preview
- add validation file generation
- add a status panel for GitHub setup

Bad tasks:
- rewrite the entire app architecture without need
- replace the GUI framework casually
- refactor unrelated modules while fixing one bug
- add large speculative systems not needed for v1

---

## Architecture Expectations

Keep concerns separated.

Preferred modules or equivalents:
- UI
- settings/state
- project scaffolding/generation
- template rendering
- git integration
- github integration
- validation generation
- prompt generation
- utilities

If the repo already has a structure, extend it consistently rather than inventing a new one.

---

## UI Expectations

The UI should be:
- simple
- fast
- legible
- low-friction
- explicit about what it is doing

The UI must:
- show important status clearly
- expose errors clearly
- show what files/actions will be created when practical
- avoid hidden side effects

A log panel is strongly preferred for all automation steps.

---

## File Generation Rules

Generated project files should be:
- deterministic
- readable
- editable by humans
- minimal but useful
- safe defaults for Codex workflows

When generating project scaffolds:
- use predictable folder structures
- create only files that serve a clear purpose
- keep templates lightweight
- avoid placeholder bloat

---

## Subprocess Rules

Any subprocess usage must:
- check tool availability first
- capture stdout/stderr where useful
- surface errors to the user
- use safe argument handling
- avoid shell injection risks
- avoid blocking the UI unnecessarily

This applies especially to:
- `git`
- `gh`
- `godot`

---

## Git and GitHub Rules

For Git:
- initialize only when appropriate
- make clear initial commits
- report failures clearly

For GitHub:
- use `gh` only if installed and authenticated
- fail gracefully if unavailable
- provide actionable next steps instead of crashing
- do not assume repo creation succeeded without checking results

---

## Settings and Persistence

If storing user defaults, persist only what is useful, such as:
- base directory
- GitHub username
- preferred repo visibility
- preferred template
- preferred Godot version
- last used options

Settings must be easy to inspect and safe to reset.

---

## Safety and Data Protection

Agents must protect user work.

Always:
- check whether a target path already exists
- offer non-destructive alternatives
- prefer creating a suffixed folder over overwriting
- preserve user-created files unless explicitly instructed otherwise

Never assume temporary files are safe to delete unless the code clearly controls them.

---

## Validation Expectations

When changing behavior, validate at the smallest practical level.

Possible validation methods:
- run the app locally
- run unit tests if present
- validate template output
- validate generated file trees
- test subprocess availability checks
- test dry run output

If full runtime validation is not possible, state that clearly and provide the closest verified result.

---

## Reporting Format

Agents should report work in this structure:

### Changes
- files changed
- brief summary of implementation

### Validation
- what was run or checked
- result

### Status
- success / partial / failed

### Uncertainty
- anything not fully verified
- anything that still needs manual confirmation

Do not claim completion if runtime behavior was not actually checked.

---

## Prompt Generation Feature Guidance

If working on prompt generation:
- generate prompts that are specific and actionable
- include project-specific paths and files when available
- avoid vague “make it better” style prompts
- favor small, bounded requests
- include validation instructions where relevant

---

## Template Guidance

Templates should be:
- lightweight
- clear
- extendable
- useful immediately

For generated Godot project templates:
- keep the starter footprint small
- avoid too many opinions in v1
- make Codex-oriented files explicit
- prioritize repeatable validation over flashy examples

---

## V2 Roadmap

V2 should focus on polish, trust, and stronger Codex handoff.

The goal is not to add a random backlog of features.
The goal is to make project creation easier to trust, easier to inspect, and easier to continue in Codex without guesswork.

V2 work should be grouped into these themes:

### 1. Visibility and Trust

- post-create project summary panel
- Git and GitHub status indicators
- copyable file tree or project manifest

### 2. Codex Handoff Quality

- stronger template-aware prompt pack
- improved `run_validation.sh` workflow
- safe Open in Codex handoff flow

### 3. Creation UX

- Finder-based base directory picker
- recent projects list

### 4. Repeatability

- reusable configuration presets
- expanded lightweight templates

V2 tasks should improve confidence, visibility, or repeatability directly.
Avoid adding features that do not clearly strengthen one of these themes.

---

## V2 Should Avoid

- cloud sync
- plugin marketplace
- speculative framework rewrite
- oversized template system
- overengineering

---

## Debugging Protocol

If behavior is unclear:

1. do not guess
2. inspect current code flow
3. add targeted logging if appropriate
4. reproduce with the smallest possible case
5. fix the root cause
6. remove or minimize temporary debugging noise afterward

---

## Change Restraint

Agents must avoid:
- style-only edits unless requested
- opportunistic rewrites
- renaming files or modules casually
- changing framework choices without a strong reason
- introducing background services or network dependencies unnecessarily

---

## Documentation Expectations

When adding or changing major behavior:
- keep README or relevant docs in sync
- document new settings or workflow changes
- document required external tools if applicable

Documentation should help a user run the app locally on macOS with minimal confusion.

---

## V3 Directions

The next version should focus on making Game Factory useful after project creation, not just during setup.

Priority areas:
1. Editable workflow files
- built-in editor for `AGENTS.md`, `README.md`, and `run_validation.sh`
- regenerate and restore workflow files safely

2. Project lifecycle tools
- inspect existing projects
- audit project health
- edit per-project workflow settings

3. Asset readiness
- import starter assets
- optional asset starter packs
- asset-aware prompt generation

4. Tool handoff
- Open in Godot
- export/share project handoff bundle

---

## v1 Bias

For v1, prioritize:
1. project creation
2. folder/file generation
3. Git initialization
4. optional GitHub creation
5. workflow file generation
6. visible logs
7. stable UX

Do not delay a working v1 for speculative extensibility.

---

## Summary

This repo exists to build a **repeatable project factory** for Codex-friendly Godot development.

Agents should build software that is:
- practical
- inspectable
- local-first
- safe
- deterministic
- easy to use
- easy to maintain

When in doubt:
- choose the simpler implementation
- preserve user work
- make behavior visible
- keep changes small
- ship the useful version first
