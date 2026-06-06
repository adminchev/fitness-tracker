import Foundation
import SwiftData

/// History lookups shared by the standard and accessible loggers, so "last time"
/// hints, suggestion chips, and add-set prefill all read the past identically.
@MainActor
enum PreviousSession {
    /// Sets from the most recent *earlier* workout that logged the same exercise
    /// definition, optionally narrowed to one side. Empty when there's no prior session.
    static func sets(for exercise: Exercise, on side: SetSide? = nil) -> [WorkoutSet] {
        guard let definition = exercise.definition,
              let currentDate = exercise.workout?.date else { return [] }
        let priorSessions = (definition.exercises ?? []).filter { other in
            guard let date = other.workout?.date else { return false }
            return other.persistentModelID != exercise.persistentModelID && date < currentDate
        }
        guard let mostRecent = priorSessions.max(by: {
            ($0.workout?.date ?? .distantPast) < ($1.workout?.date ?? .distantPast)
        }) else { return [] }
        let sets = (mostRecent.sets ?? []).sortedByOrder()
        guard let side else { return sets }
        return sets.filter { $0.side == side.rawValue }
    }

    /// A short "20 × 12" / "L 30s" summary of one set, for the "last time" hint.
    static func describe(_ set: WorkoutSet, isTimed: Bool) -> String {
        let sidePrefix = set.side.isEmpty ? "" : "\(set.side) "
        let load = set.weight.map { "\(format($0)) × " } ?? ""
        let core = isTimed
            ? "\(set.durationSeconds.map(String.init) ?? "—")s"
            : (set.reps.map(String.init) ?? "—")
        return sidePrefix + load + core
    }

    private static func format(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
    }
}
