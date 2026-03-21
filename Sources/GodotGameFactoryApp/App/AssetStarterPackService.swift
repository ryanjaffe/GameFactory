import Foundation

struct AssetStarterPackService {
    func availablePacks() -> [AssetStarterPack] {
        [
            AssetStarterPack(
                kind: .uiPlaceholder,
                title: "UI Placeholder Pack",
                description: "Simple placeholder UI shapes and notes for menus, overlays, and HUD work.",
                files: [
                    GeneratedAssetFile(
                        relativePath: "ui/button_placeholder.svg",
                        contents: """
                        <svg xmlns="http://www.w3.org/2000/svg" width="320" height="96" viewBox="0 0 320 96">
                          <rect width="320" height="96" rx="18" fill="#1f2937"/>
                          <rect x="6" y="6" width="308" height="84" rx="14" fill="#f59e0b"/>
                          <text x="160" y="56" text-anchor="middle" font-family="Helvetica, Arial, sans-serif" font-size="28" fill="#111827">BUTTON</text>
                        </svg>
                        """
                    ),
                    GeneratedAssetFile(
                        relativePath: "ui/panel_placeholder.svg",
                        contents: """
                        <svg xmlns="http://www.w3.org/2000/svg" width="480" height="270" viewBox="0 0 480 270">
                          <rect width="480" height="270" rx="20" fill="#0f172a"/>
                          <rect x="10" y="10" width="460" height="250" rx="14" fill="#e2e8f0"/>
                          <text x="240" y="145" text-anchor="middle" font-family="Helvetica, Arial, sans-serif" font-size="26" fill="#334155">UI PANEL</text>
                        </svg>
                        """
                    ),
                    GeneratedAssetFile(
                        relativePath: "ui/ui_placeholder_notes.txt",
                        contents: """
                        UI Placeholder Pack
                        - button_placeholder.svg
                        - panel_placeholder.svg

                        Replace these shapes with project-specific UI art when ready.
                        """
                    ),
                ]
            ),
            AssetStarterPack(
                kind: .platformerPlaceholder,
                title: "Simple Platformer Placeholder Pack",
                description: "Tiny placeholder sprites and notes suited to a platformer prototype.",
                files: [
                    GeneratedAssetFile(
                        relativePath: "sprites/platformer_player_placeholder.svg",
                        contents: """
                        <svg xmlns="http://www.w3.org/2000/svg" width="64" height="96" viewBox="0 0 64 96">
                          <rect x="12" y="8" width="40" height="80" rx="12" fill="#2563eb"/>
                          <circle cx="32" cy="28" r="10" fill="#bfdbfe"/>
                          <rect x="20" y="46" width="24" height="8" rx="4" fill="#bfdbfe"/>
                        </svg>
                        """
                    ),
                    GeneratedAssetFile(
                        relativePath: "sprites/platformer_tile_placeholder.svg",
                        contents: """
                        <svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">
                          <rect width="64" height="64" fill="#14532d"/>
                          <rect x="4" y="4" width="56" height="16" fill="#22c55e"/>
                          <rect x="8" y="24" width="20" height="12" fill="#16a34a"/>
                          <rect x="34" y="24" width="22" height="12" fill="#16a34a"/>
                        </svg>
                        """
                    ),
                    GeneratedAssetFile(
                        relativePath: "sprites/platformer_pack_notes.txt",
                        contents: """
                        Platformer Placeholder Pack
                        - platformer_player_placeholder.svg
                        - platformer_tile_placeholder.svg

                        Use these as temporary stand-ins while wiring movement and collision.
                        """
                    ),
                ]
            ),
            AssetStarterPack(
                kind: .dialoguePlaceholder,
                title: "Dialogue Placeholder Pack",
                description: "Minimal dialogue UI placeholders and starter notes for narrative scenes.",
                files: [
                    GeneratedAssetFile(
                        relativePath: "ui/dialogue_box_placeholder.svg",
                        contents: """
                        <svg xmlns="http://www.w3.org/2000/svg" width="640" height="180" viewBox="0 0 640 180">
                          <rect width="640" height="180" rx="20" fill="#111827"/>
                          <rect x="14" y="14" width="612" height="152" rx="16" fill="#f8fafc"/>
                          <text x="320" y="92" text-anchor="middle" font-family="Helvetica, Arial, sans-serif" font-size="28" fill="#1f2937">DIALOGUE BOX</text>
                        </svg>
                        """
                    ),
                    GeneratedAssetFile(
                        relativePath: "dialogue/dialogue_portrait_placeholder.svg",
                        contents: """
                        <svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">
                          <rect width="128" height="128" rx="18" fill="#7c3aed"/>
                          <circle cx="64" cy="46" r="24" fill="#ede9fe"/>
                          <rect x="30" y="76" width="68" height="28" rx="14" fill="#ede9fe"/>
                        </svg>
                        """
                    ),
                    GeneratedAssetFile(
                        relativePath: "dialogue/dialogue_pack_notes.txt",
                        contents: """
                        Dialogue Placeholder Pack
                        - dialogue_box_placeholder.svg
                        - dialogue_portrait_placeholder.svg

                        Use these for temporary dialogue layout and speaker presentation.
                        """
                    ),
                ]
            ),
        ]
    }

    func pack(for kind: AssetStarterPackKind) -> AssetStarterPack? {
        availablePacks().first(where: { $0.kind == kind })
    }
}

struct AssetStarterPack: Identifiable {
    let kind: AssetStarterPackKind
    let title: String
    let description: String
    let files: [GeneratedAssetFile]

    var id: String { kind.rawValue }
}

enum AssetStarterPackKind: String, CaseIterable, Identifiable {
    case uiPlaceholder
    case platformerPlaceholder
    case dialoguePlaceholder

    var id: String { rawValue }
}
