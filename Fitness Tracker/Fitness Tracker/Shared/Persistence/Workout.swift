import Foundation
import SwiftData

@Model final class Workout {
    var date: Date = Date()
    var name: String = ""
    var notes: String = ""
    @Relationship(deleteRule: .nullify) var trainingPlan: TrainingPlan? = nil
    @Relationship(deleteRule: .cascade, inverse: \Exercise.workout) var exercises: [Exercise]? = []

    init(name: String = "", date: Date = Date(), notes: String = "") {
        self.name = name
        self.date = date
        self.notes = notes
    }
}
