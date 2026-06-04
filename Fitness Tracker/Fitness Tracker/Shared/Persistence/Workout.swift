import Foundation
import SwiftData

/// One training session: a dated bag of exercises, optionally created from a `TrainingPlan`.
@Model final class Workout {
    var date: Date = Date()
    var name: String = ""
    var notes: String = ""
    /// The plan this session was started from (kept for reference; nullified if the plan is deleted).
    @Relationship(deleteRule: .nullify) var trainingPlan: TrainingPlan? = nil
    /// Deleting a workout cascades to its exercises (and their sets).
    @Relationship(deleteRule: .cascade, inverse: \Exercise.workout) var exercises: [Exercise]? = []

    init(name: String = "", date: Date = Date(), notes: String = "") {
        self.name = name
        self.date = date
        self.notes = notes
    }
}
