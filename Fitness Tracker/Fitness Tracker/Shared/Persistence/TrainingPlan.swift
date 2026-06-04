import Foundation
import SwiftData

/// A named, reusable plan (e.g. "Phase 1 — Foundation"). Starting a workout from a
/// plan copies its `templateExercises` into the new session.
@Model final class TrainingPlan {
    var name: String = ""
    var order: Int = 0
    /// Coaching blurb shown at the top of the plan.
    var summary: String = ""
    /// Created by the initial seed; protected from deletion in the UI.
    var isSeeded: Bool = false
    @Relationship(deleteRule: .cascade, inverse: \TemplateExercise.plan) var templateExercises: [TemplateExercise]? = []

    init(name: String = "", order: Int = 0, summary: String = "") {
        self.name = name
        self.order = order
        self.summary = summary
    }
}
