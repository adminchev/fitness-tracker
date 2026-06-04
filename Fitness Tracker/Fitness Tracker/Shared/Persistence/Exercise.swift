import Foundation
import SwiftData

@Model final class Exercise {
    var name: String = ""
    var order: Int = 0
    var targetSummary: String = ""
    var notes: String = ""
    var isTimed: Bool = false
    var tracksSides: Bool = false
    var equipmentRaw: String = Equipment.freeWeight.rawValue
    /// Prescribed RPE for this exercise (parsed from the plan), used to auto-fill sets and score adherence.
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
}
