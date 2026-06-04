import Foundation

enum ProgressMetric: String, CaseIterable, Identifiable {
    case oneRepMax = "1RM"
    case topWeight = "Top wt"
    case volume = "Volume"
    case totalReps = "Reps"
    var id: String { rawValue }
}

enum ProgressRange: String, CaseIterable, Identifiable {
    case month = "1M"
    case threeMonths = "3M"
    case year = "1Y"
    var id: String { rawValue }
    var days: Int {
        switch self {
        case .month: 30
        case .threeMonths: 90
        case .year: 365
        }
    }
    var label: String {
        switch self {
        case .month: "the last month"
        case .threeMonths: "the last 3 months"
        case .year: "the last year"
        }
    }
}

/// How closely a session's logged RPE matched the prescribed target.
enum Adherence {
    case onTarget, near, off, unknown
}

struct MetricPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    let side: String          // "", "L", "R"
    let adherence: Adherence
    let breakdown: String     // e.g. "42.5×8, 40×10"
}

@MainActor
enum ProgressCalculator {
    /// Epley estimated one-rep max for a single set.
    static func oneRepMax(_ set: WorkoutSet) -> Double {
        guard let reps = set.reps, let weight = set.weight, reps > 0, weight > 0 else { return 0 }
        return weight * (1.0 + Double(reps) / 30.0)
    }

    static func sessionValue(_ sets: [WorkoutSet], metric: ProgressMetric) -> Double {
        switch metric {
        case .oneRepMax: return sets.map(oneRepMax).max() ?? 0
        case .topWeight: return sets.compactMap(\.weight).max() ?? 0
        case .volume: return sets.reduce(0) { $0 + volume(of: $1) }
        case .totalReps: return sets.reduce(0) { $0 + Double($1.reps ?? 0) }
        }
    }

    private static func volume(of set: WorkoutSet) -> Double {
        let load = set.weight ?? 0
        if let duration = set.durationSeconds, duration > 0 {
            return load > 0 ? load * Double(duration) : Double(duration)
        }
        return load * Double(set.reps ?? 0)
    }

    static func adherence(of sets: [WorkoutSet], target: Double?) -> Adherence {
        guard let target else { return .unknown }
        let rpes = sets.compactMap(\.rpe)
        guard !rpes.isEmpty else { return .unknown }
        let average = rpes.reduce(0, +) / Double(rpes.count)
        let delta = abs(average - target)
        if delta <= 0.5 { return .onTarget }
        if delta <= 1.0 { return .near }
        return .off
    }

    /// Chart points for the given exercises, optionally filtered to one side.
    /// One point per logged session, so scrubbing keeps full resolution.
    static func points(for exercises: [Exercise], metric: ProgressMetric, range: ProgressRange, side: SetSide? = nil, now: Date = Date()) -> [MetricPoint] {
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .day, value: -range.days, to: now) ?? .distantPast
        return exercises.compactMap { exercise -> MetricPoint? in
            guard let date = exercise.workout?.date, date >= cutoff else { return nil }
            let sets = filtered(exercise.sets ?? [], side: side)
            guard !sets.isEmpty else { return nil }
            let value = sessionValue(sets, metric: metric)
            guard value > 0 else { return nil }
            return MetricPoint(
                date: date,
                value: value,
                side: side?.rawValue ?? "",
                adherence: adherence(of: sets, target: exercise.targetRPE),
                breakdown: breakdown(sets, isTimed: exercise.isTimed)
            )
        }
        .sorted { $0.date < $1.date }
    }

    static func best(for exercises: [Exercise], metric: ProgressMetric, side: SetSide? = nil) -> Double {
        exercises.compactMap { exercise -> Double? in
            let value = sessionValue(filtered(exercise.sets ?? [], side: side), metric: metric)
            return value > 0 ? value : nil
        }.max() ?? 0
    }

    private static func filtered(_ sets: [WorkoutSet], side: SetSide?) -> [WorkoutSet] {
        guard let side else { return sets }
        return sets.filter { $0.side == side.rawValue }
    }

    private static func breakdown(_ sets: [WorkoutSet], isTimed: Bool) -> String {
        sets.sortedByOrder().map { set in
            let load = set.weight.map { "\(formatted($0))×" } ?? ""
            let core = isTimed ? "\(set.durationSeconds ?? 0)s" : "\(set.reps ?? 0)"
            return load + core
        }.joined(separator: ", ")
    }

    private static func formatted(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
    }
}
