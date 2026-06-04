import Foundation
import SwiftData

@Model final class WorkoutSet {
    var reps: Int? = nil
    /// The external load — kg for free-weight/cable, band rating for bands. nil = not recorded.
    var weight: Double? = nil
    var durationSeconds: Int? = nil
    var rpe: Double? = nil
    /// "" = unspecified, otherwise "L" / "R".
    var side: String = ""
    var notes: String = ""
    var order: Int = 0
    var exercise: Exercise? = nil

    init(reps: Int? = nil, weight: Double? = nil, durationSeconds: Int? = nil, rpe: Double? = nil, side: String = "", order: Int = 0) {
        self.reps = reps
        self.weight = weight
        self.durationSeconds = durationSeconds
        self.rpe = rpe
        self.side = side
        self.order = order
    }
}
