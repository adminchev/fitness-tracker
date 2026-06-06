import Foundation
import SwiftData

/// One editable field of a set, in the order the guided logger walks them.
enum LogField: Equatable {
    case weight, reps, duration, effort
}

/// A single step of the guided flow: which set, which field, and the set's position
/// within its side (for the "Set n of m" header).
struct LogStep {
    let set: WorkoutSet
    let field: LogField
    let setNumber: Int
    let setCount: Int
}

/// Pure construction of the accessible logger's step sequence for one exercise —
/// kept out of the view so it can be unit-tested directly.
@MainActor
enum GuidedLogger {
    /// Ordered (set, field) steps. Unilateral exercises are walked lead-arm first and
    /// numbered within each side; every set emits its fields as weight (loaded only) →
    /// reps-or-duration → effort.
    static func steps(for exercise: Exercise) -> [LogStep] {
        let all = (exercise.sets ?? []).sortedByOrder()

        // Group sets by the side we'll present them in (lead arm first), or a single
        // unsided group for bilateral exercises.
        let groups: [[WorkoutSet]]
        if exercise.tracksSides {
            let lead = AppSettings.leadSide
            groups = [lead, lead.opposite].map { side in
                all.filter { $0.side == side.rawValue }
            }
        } else {
            groups = [all]
        }

        let hasWeight = exercise.equipment.loadUnit != nil
        var steps: [LogStep] = []
        for group in groups {
            for (index, set) in group.enumerated() {
                var fields: [LogField] = []
                if hasWeight { fields.append(.weight) }
                fields.append(exercise.isTimed ? .duration : .reps)
                fields.append(.effort)
                for field in fields {
                    steps.append(LogStep(set: set, field: field,
                                         setNumber: index + 1, setCount: group.count))
                }
            }
        }
        return steps
    }
}
