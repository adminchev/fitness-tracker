import Foundation
import SwiftData

enum ConsistencyRange: String, CaseIterable, Identifiable {
    case twoWeeks = "2W"
    case month = "1M"
    case threeMonths = "3M"
    case sixMonths = "6M"
    var id: String { rawValue }

    /// Short ranges bucket by day; longer ranges bucket by week.
    var bucketUnit: Calendar.Component { self == .twoWeeks ? .day : .weekOfYear }
    var bucketCount: Int {
        switch self {
        case .twoWeeks: 14
        case .month: 5
        case .threeMonths: 13
        case .sixMonths: 26
        }
    }
    var days: Int {
        switch self {
        case .twoWeeks: 14
        case .month: 30
        case .threeMonths: 90
        case .sixMonths: 180
        }
    }
}

struct ConsistencyBar: Identifiable {
    let id = UUID()
    let start: Date
    let count: Int
}

/// Backs `ProgressDashboardView`: fetches sessions + trained exercises and computes
/// the consistency stats. Date-reading methods take an injectable `now:` for testing.
@Observable final class ProgressDashboardViewModel {
    var workouts: [Workout] = []
    var trainedDefinitions: [ExerciseDefinition] = []

    func load(in context: ModelContext) {
        let workoutDescriptor = FetchDescriptor<Workout>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        workouts = (try? context.fetch(workoutDescriptor)) ?? []

        let definitionDescriptor = FetchDescriptor<ExerciseDefinition>(sortBy: [SortDescriptor(\.name)])
        let definitions = (try? context.fetch(definitionDescriptor)) ?? []
        trainedDefinitions = definitions.filter { definition in
            (definition.exercises ?? []).contains { $0.sets?.isEmpty == false }
        }
    }

    var totalWorkouts: Int { workouts.count }

    // `now` is injectable so the date-bucketing logic can be tested deterministically.
    func workoutsThisWeek(now: Date = Date()) -> Int { count(in: .weekOfYear, now: now) }
    func workoutsThisMonth(now: Date = Date()) -> Int { count(in: .month, now: now) }

    private func count(in component: Calendar.Component, now: Date) -> Int {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: component, for: now) else { return 0 }
        return workouts.filter { interval.contains($0.date) }.count
    }

    /// Average gap in days between consecutive sessions within the window.
    func averageRecoveryDays(in range: ConsistencyRange, now: Date = Date()) -> Double? {
        let calendar = Calendar.current
        guard let cutoff = calendar.date(byAdding: .day, value: -range.days, to: now) else { return nil }
        let dates = workouts.map(\.date).filter { $0 >= cutoff }.sorted()
        guard dates.count >= 2 else { return nil }
        let gaps = zip(dates.dropFirst(), dates).map { $0.timeIntervalSince($1) / 86_400 }
        return gaps.reduce(0, +) / Double(gaps.count)
    }

    func bars(for range: ConsistencyRange, now: Date = Date()) -> [ConsistencyBar] {
        let calendar = Calendar.current
        var bars: [ConsistencyBar] = []
        for offset in stride(from: range.bucketCount - 1, through: 0, by: -1) {
            guard let day = calendar.date(byAdding: range.bucketUnit, value: -offset, to: now),
                  let interval = calendar.dateInterval(of: range.bucketUnit, for: day) else { continue }
            let count = workouts.filter { interval.contains($0.date) }.count
            bars.append(ConsistencyBar(start: interval.start, count: count))
        }
        return bars
    }
}
