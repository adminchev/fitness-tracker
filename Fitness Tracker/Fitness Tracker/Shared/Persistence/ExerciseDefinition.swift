import Foundation
import SwiftData

@Model final class ExerciseDefinition {
    var name: String = ""
    var createdAt: Date = Date()
    /// True for catalog entries created by the initial seed; these are protected from deletion.
    var isSeeded: Bool = false
    /// True for isometric holds — sets log a duration (seconds) instead of reps.
    var isTimed: Bool = false
    /// True for unilateral movements — sets carry an L/R side tag.
    var tracksSides: Bool = false
    var equipmentRaw: String = Equipment.freeWeight.rawValue
    @Relationship(deleteRule: .nullify, inverse: \Exercise.definition) var exercises: [Exercise]? = []
    @Relationship(deleteRule: .nullify, inverse: \TemplateExercise.definition) var templateExercises: [TemplateExercise]? = []

    init(name: String = "") {
        self.name = name
    }

    var equipment: Equipment {
        Equipment(rawValue: equipmentRaw) ?? .freeWeight
    }
}
