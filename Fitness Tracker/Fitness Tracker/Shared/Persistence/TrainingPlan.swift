import Foundation
import SwiftData

@Model final class TrainingPlan {
    var name: String = ""
    var order: Int = 0
    var summary: String = ""
    /// True for plans created by the initial seed; these are protected from deletion.
    var isSeeded: Bool = false
    @Relationship(deleteRule: .cascade, inverse: \TemplateExercise.plan) var templateExercises: [TemplateExercise]? = []

    init(name: String = "", order: Int = 0, summary: String = "") {
        self.name = name
        self.order = order
        self.summary = summary
    }
}
