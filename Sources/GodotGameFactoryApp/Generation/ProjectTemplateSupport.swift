import Foundation

struct ProjectTemplateSupport {
    static func validationTarget(for template: ProjectTemplate) -> String? {
        switch template {
        case .blank:
            return nil
        case .platformerStarter:
            return "scenes/platformer_playground.tscn"
        case .topDownStarter:
            return "scenes/top_down_playground.tscn"
        }
    }

    static func validationNotesFilename(for template: ProjectTemplate) -> String {
        switch template {
        case .blank:
            return "tests/validation_notes.md"
        case .platformerStarter:
            return "tests/platformer_starter_notes.md"
        case .topDownStarter:
            return "tests/top_down_starter_notes.md"
        }
    }

    static func validationNotesContents(for template: ProjectTemplate) -> String {
        switch template {
        case .blank:
            return """
            # Validation Notes

            Suggested first checks:

            - Open the project in Godot and let the editor finalize `project.godot`
            - Confirm the scaffold folders are present and readable
            - Run `./run_validation.sh` and review output in `artifacts/`
            """
        case .platformerStarter:
            return """
            # Platformer Starter Notes

            Suggested first checks:

            - Attach `scripts/platformer_player.gd` to a `CharacterBody2D`
            - Add a floor collision shape
            - Confirm left/right movement and jump input
            - Run `./run_validation.sh` and capture notes in `artifacts/`
            """
        case .topDownStarter:
            return """
            # Top-Down Starter Notes

            Suggested first checks:

            - Attach `scripts/top_down_player.gd` to a `CharacterBody2D`
            - Add a visible sprite and basic collision
            - Confirm four-direction movement input
            - Run `./run_validation.sh` and capture notes in `artifacts/`
            """
        }
    }

    static func additionalFiles(
        for template: ProjectTemplate,
        projectURL: URL
    ) -> [(url: URL, contents: String)] {
        switch template {
        case .blank:
            return [
                (
                    projectURL.appendingPathComponent(validationNotesFilename(for: template)),
                    validationNotesContents(for: template)
                ),
            ]
        case .platformerStarter:
            return [
                (
                    projectURL.appendingPathComponent("scripts/platformer_player.gd"),
                    """
                    extends CharacterBody2D

                    # Platformer starter placeholder.
                    # Replace these values after testing movement in Godot.
                    @export var move_speed: float = 220.0
                    @export var jump_velocity: float = -360.0
                    @export var gravity_strength: float = 980.0

                    func _physics_process(delta: float) -> void:
                        if not is_on_floor():
                            velocity.y += gravity_strength * delta

                        var input_axis := Input.get_axis("ui_left", "ui_right")
                        velocity.x = input_axis * move_speed

                        if Input.is_action_just_pressed("ui_accept") and is_on_floor():
                            velocity.y = jump_velocity

                        move_and_slide()
                    """
                ),
                (
                    projectURL.appendingPathComponent("scenes/platformer_playground.tscn"),
                    """
                    [gd_scene format=3]

                    [node name="PlatformerPlayground" type="Node2D"]

                    [node name="Notes" type="Label" parent="."]
                    text = "Platformer starter placeholder scene. Add a Player node and a floor to test movement."
                    """
                ),
                (
                    projectURL.appendingPathComponent(validationNotesFilename(for: template)),
                    validationNotesContents(for: template)
                ),
            ]
        case .topDownStarter:
            return [
                (
                    projectURL.appendingPathComponent("scripts/top_down_player.gd"),
                    """
                    extends CharacterBody2D

                    # Top-down starter placeholder.
                    @export var move_speed: float = 200.0

                    func _physics_process(_delta: float) -> void:
                        var input_vector := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
                        velocity = input_vector * move_speed
                        move_and_slide()
                    """
                ),
                (
                    projectURL.appendingPathComponent("scenes/top_down_playground.tscn"),
                    """
                    [gd_scene format=3]

                    [node name="TopDownPlayground" type="Node2D"]

                    [node name="Notes" type="Label" parent="."]
                    text = "Top-down starter placeholder scene. Add a Player node and some walls to test movement."
                    """
                ),
                (
                    projectURL.appendingPathComponent(validationNotesFilename(for: template)),
                    validationNotesContents(for: template)
                ),
            ]
        }
    }

    static func readmeNotes(for template: ProjectTemplate) -> [String] {
        switch template {
        case .blank:
            return [
                "This is the minimal blank scaffold.",
                "Includes `run_validation.sh` as a starter validation entrypoint.",
                "Includes `tests/validation_notes.md` with small validation steps.",
            ]
        case .platformerStarter:
            return [
                "Includes `scripts/platformer_player.gd` as a platformer movement placeholder.",
                "Includes `scenes/platformer_playground.tscn` for a first movement sandbox.",
                "Includes `run_validation.sh` as a starter validation entrypoint.",
                "Includes `tests/platformer_starter_notes.md` with small validation steps.",
            ]
        case .topDownStarter:
            return [
                "Includes `scripts/top_down_player.gd` as a top-down movement placeholder.",
                "Includes `scenes/top_down_playground.tscn` for a first movement sandbox.",
                "Includes `run_validation.sh` as a starter validation entrypoint.",
                "Includes `tests/top_down_starter_notes.md` with small validation steps.",
            ]
        }
    }
}
