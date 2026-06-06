import Foundation
import SwiftData

/// One movement performed within a session. Equipment / timed / side flags are
/// copied from the `ExerciseDefinition` at creation so the row can render
/// correctly even if the catalog entry is later deleted.
@Model final class Exercise {
    var name: String = ""
    var order: Int = 0
    /// Prescription guidance copied from the plan, shown in the session ("3 × 15–20 · RPE 6").
    var targetSummary: String = ""
    var notes: String = ""
    /// Holds log seconds instead of reps.
    var isTimed: Bool = false
    /// Unilateral — sets carry an L/R side and the row shows a Left/Right tab.
    var tracksSides: Bool = false
    var equipmentRaw: String = Equipment.freeWeight.rawValue
    /// Prescribed RPE; auto-fills each set's RPE and is the baseline for adherence colouring.
    var targetRPE: Double? = nil
    var workout: Workout? = nil
    var definition: ExerciseDefinition? = nil
    @Relationship(deleteRule: .cascade, inverse: \WorkoutSet.exercise) var sets: [WorkoutSet]? = []

    init(name: String = "", order: Int = 0, targetSummary: String = "", notes: String = "") {
        self.name = name
        self.order = order
        self.targetSummary = targetSummary
        self.notes = notes
    }

    var equipment: Equipment {
        Equipment(rawValue: equipmentRaw) ?? .freeWeight
    }

    /// The load increment for steppers and suggestion chips: the catalog entry's
    /// custom step if set, otherwise the equipment default.
    var loadStep: Double {
        definition?.stepKg ?? equipment.loadStep
    }
}
