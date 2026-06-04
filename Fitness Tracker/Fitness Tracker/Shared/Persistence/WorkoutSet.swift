import Foundation
import SwiftData

/// One logged set. Every measurement is optional so that a blank field means
/// "not recorded" rather than a real zero (an empty weight ≠ 0 kg).
@Model final class WorkoutSet {
    var reps: Int? = nil
    /// The external load — kg for free-weight/cable, a band rating for bands. `nil` = not recorded.
    var weight: Double? = nil
    /// Hold duration for timed (isometric) exercises.
    var durationSeconds: Int? = nil
    var rpe: Double? = nil
    /// Raw `SetSide` value: "" (none), "L", or "R". Use `sideTag` for a typed view.
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

    /// Typed accessor over the raw `side` string, so call sites avoid "L"/"R" literals.
    var sideTag: SetSide? {
        get { SetSide(rawValue: side) }
        set { side = newValue?.rawValue ?? "" }
    }
}
