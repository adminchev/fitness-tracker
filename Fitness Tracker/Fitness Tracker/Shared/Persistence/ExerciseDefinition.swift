import Foundation
import SwiftData

/// A canonical, reusable exercise — the "catalog" entry that both plans and logged
/// sessions point at, so progress can be grouped across time. The catalog grows
/// itself: the picker creates a new definition whenever you log a novel movement.
@Model final class ExerciseDefinition {
    var name: String = ""
    var createdAt: Date = Date()
    /// Created by the initial seed; these are protected from deletion in the UI.
    var isSeeded: Bool = false
    /// Isometric hold — sets log a duration (seconds) instead of reps.
    var isTimed: Bool = false
    /// Unilateral movement — sets carry an L/R side tag.
    var tracksSides: Bool = false
    var equipmentRaw: String = Equipment.freeWeight.rawValue
    /// `.nullify`: deleting a definition unlinks history but never deletes logged work.
    @Relationship(deleteRule: .nullify, inverse: \Exercise.definition) var exercises: [Exercise]? = []
    @Relationship(deleteRule: .nullify, inverse: \TemplateExercise.definition) var templateExercises: [TemplateExercise]? = []

    init(name: String = "") {
        self.name = name
    }

    var equipment: Equipment {
        Equipment(rawValue: equipmentRaw) ?? .freeWeight
    }
}
