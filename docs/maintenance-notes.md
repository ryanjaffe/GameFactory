# Maintenance Notes

This note documents a few behaviors that are easy to regress while changing the macOS app.

## Active Project Resolution

`AppViewModel` resolves the active project in this order:

1. explicitly selected recent project
2. inspected project
3. last-created project

That precedence is intentional. Do not change it casually, and do not add fallback paths that bypass it.

## Prompt Pack Targeting

Prompt-pack and starter-prompt actions must always use the active project, not just the last-created project.

This matters because the user can inspect a different project or promote a recent project to the active target. If prompt generation falls back to the last-created project, the app quietly produces the wrong paths, template context, and handoff prompt.

## UI Shell Constraints

The app intentionally avoids a few macOS SwiftUI patterns here:

- `NavigationSplitView`
- `List`-based sidebar navigation
- fragile nested text bindings like `$viewModel.settings.projectName`

These choices are deliberate. Earlier versions hit macOS input/focus problems where fields rendered and focused but would not accept typing reliably. The current shell uses a state-driven sidebar, explicit bindings for form fields, and an AppKit-hosted window path. Preserve that unless there is a proven reason to revisit it.

## Inline Status Messages

Inline UI status messages live in `AppViewModel` as small per-section `UIStatusMessage?` properties, including:

- `createProjectStatus`
- `promptPackStatus`
- `handoffBundleStatus`
- `assetImportStatus`
- `workflowFileStatus`
- `activeProjectStatus`

Rendering is centralized in `InlineStatusMessageView` in `MainView.swift`. Prefer reusing that pattern instead of adding ad hoc banners or modal alerts for ordinary success/failure feedback.

## Tests Protecting This Behavior

Active-project behavior is covered in:

- [AppViewModelActiveProjectTests.swift](/Users/ryan/Documents/CODEX/GameFactory/Tests/GodotGameFactoryAppTests/AppViewModelActiveProjectTests.swift)

Those tests currently protect:

- no project source -> no active project
- last-created project becomes active when it is the only source
- inspected project overrides last-created
- selected recent project overrides inspected and last-created
- starter prompt uses the active project rather than the stale last-created project

If you touch active-project logic or prompt-pack targeting, update or extend those tests in the same change.
