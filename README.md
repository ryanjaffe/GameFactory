# Godot Game Factory

Godot Game Factory is a local macOS app for creating **Codex-friendly Godot project scaffolds**.

Its job is to remove setup friction and make the boring parts of starting a game project fast, repeatable, and inspectable.

## What it does

The app helps create new Godot projects with:

- a consistent folder structure
- Git initialization
- optional GitHub repo creation through `gh`
- Codex workflow files such as `AGENTS.md`
- validation scripts and starter test files
- reusable templates for common project types
- visible logs and safe, local execution

## Why this exists

Starting a new Godot project often involves a lot of repeated setup:

- creating folders
- initializing Git
- wiring GitHub
- adding starter files
- setting up Codex instructions
- creating repeatable validation scaffolding

This app turns that into a guided, repeatable workflow.

## Product goals

Every generated project should be:

- easy to create
- easy to inspect
- safe to modify
- ready for Codex
- ready for Git
- optionally ready for GitHub

The app is intentionally **local-first** and should not depend on cloud services for core functionality.

## v1 priorities

Version 1 focuses on:

1. project creation
2. project scaffolding
3. Git initialization
4. optional GitHub repo creation
5. Codex workflow file generation
6. validation file generation
7. clear status and logs

## Non-goals

This app is not trying to be:

- a game engine
- a full Godot editor replacement
- a launcher platform
- a cloud build system

It is a **project factory** for repeatable setup.

## Core principles

- keep setup simple
- preserve user work
- avoid destructive behavior
- make automation visible
- prefer deterministic output
- favor working software over overengineering

## Typical workflow

1. Enter project details in the GUI
2. Choose a template
3. Preview what will be created
4. Generate the project scaffold
5. Initialize Git
6. Optionally create and push a GitHub repo
7. Open the generated project and continue in Godot and Codex

## External tools

Some features depend on local tools being installed:

- `git` for repository setup
- `gh` for GitHub repo creation
- `godot` for validation-related workflows, if supported by the generated project

The app should detect missing tools and provide helpful next steps instead of failing silently.

## Current Status

What is already working:

- project scaffold generation
- safe naming collision handling
- local Git init with an initial commit
- optional GitHub setup through `gh`
- settings persistence
- dry-run / preview mode
- post-create actions for the last real project
- lightweight templates
- generated project `AGENTS.md`, `run_validation.sh`, and Codex starter prompt support

## Current implementation

The repository now contains a minimal native macOS app scaffold built with SwiftUI and Swift Package Manager.

Current architecture modules:

- `Sources/GodotGameFactoryApp/App` for app entry and top-level state
- `Sources/GodotGameFactoryApp/UI` for SwiftUI views
- `Sources/GodotGameFactoryApp/Settings` for persisted user settings models
- `Sources/GodotGameFactoryApp/Generation` for project scaffold generation
- `Sources/GodotGameFactoryApp/Integrations` for Git and GitHub integrations
- `Sources/GodotGameFactoryApp/Logging` for visible app logging

This is intentionally the smallest runnable starting point for the MVP.

## V2 Roadmap

V2 is about polish, repeatability, and stronger handoff into Codex.

The goal is not feature sprawl.
The goal is to make project creation easier to trust, easier to inspect, and easier to continue after generation.

Themes for V2:

### 1. Visibility and trust

- post-create project summary panel
- Git and GitHub status indicators
- copyable file tree or project manifest

### 2. Codex handoff quality

- stronger template-aware prompt pack
- improved `run_validation.sh` workflow
- safe Open in Codex handoff flow

### 3. Creation UX

- Finder-based base directory picker
- recent projects list

### 4. Repeatability

- reusable configuration presets
- expanded lightweight templates

## Next Recommended Build Order

1. post-create project summary panel
2. Git/GitHub status indicators
3. copyable file tree / manifest
4. improved validation runner
5. template-aware prompt pack
6. Finder-based folder picker
7. safe Open in Codex workflow
8. recent projects list
9. reusable presets
10. expanded lightweight templates

## Run locally

From the repository root:

```bash
swift run
```
