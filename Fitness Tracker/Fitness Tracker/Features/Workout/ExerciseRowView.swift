internal import SwiftUI
import SwiftData

/// One exercise inside a workout session, rendered as a `List` section.
///
/// Observes its `Exercise` directly via `@Bindable` (the single-model-edit pattern —
/// see CLAUDE.md), so set edits flow back to SwiftData without a ViewModel.
/// Unilateral exercises show a Left/Right tab and only the selected side's sets.
struct ExerciseRowView: View {
    @Bindable var exercise: Exercise
    @Environment(\.modelContext) private var modelContext

    /// Which arm is currently shown (only relevant when `exercise.tracksSides`).
    @State private var selectedSide: SetSide = .left

    private var sortedSets: [WorkoutSet] {
        (exercise.sets ?? []).sortedByOrder()
    }

    /// Sets for one side; pass `nil` for bilateral exercises (matches `side == ""`).
    private func sets(on side: SetSide?) -> [WorkoutSet] {
        sortedSets.filter { $0.side == (side?.rawValue ?? "") }
    }

    var body: some View {
        Section {
            if exercise.tracksSides {
                // Tab between arms; the section below shows only that side's sets.
                Picker("Side", selection: $selectedSide) {
                    Text("Left").tag(SetSide.left)
                    Text("Right").tag(SetSide.right)
                }
                .pickerStyle(.segmented)
                setRows(sets(on: selectedSide))
                addButton("Add Set", side: selectedSide)
            } else {
                setRows(sets(on: nil))
                addButton("Add Set", side: nil)
            }
        } header: {
            header
        } footer: {
            if !exercise.notes.isEmpty {
                Text(exercise.notes).textCase(nil)
            }
        }
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(exercise.name)
                .font(.headline)
                .textCase(nil)
            if !exercise.targetSummary.isEmpty {
                Text(exercise.targetSummary)          // e.g. "3 × 15–20 · RPE 6"
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(nil)
            }
            if let lastTimeSummary {                  // "Last: 40 × 12, 40 × 10"
                Text(lastTimeSummary)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .textCase(nil)
            }
        }
    }

    @ViewBuilder private func setRows(_ groupSets: [WorkoutSet]) -> some View {
        ForEach(Array(groupSets.enumerated()), id: \.element.persistentModelID) { index, set in
            SetRowView(set: set, setNumber: index + 1, isTimed: exercise.isTimed, equipment: exercise.equipment)
        }
        .onDelete { offsets in
            offsets.forEach { modelContext.delete(groupSets[$0]) }
        }
    }

    private func addButton(_ title: String, side: SetSide?) -> some View {
        Button {
            addSet(side: side)
        } label: {
            Label(title, systemImage: "plus.circle.fill")
                .font(.subheadline.bold())
        }
        .buttonStyle(.borderless)   // borderless so the row doesn't grab the whole-row tap
    }

    // MARK: - "Last time" reference

    /// A summary of the most recent earlier session, shown under the header so you
    /// know what to beat. Combines both sides (each tagged in the string).
    private var lastTimeSummary: String? {
        let previous = previousSets(on: nil)
        guard !previous.isEmpty else { return nil }
        return "Last: " + previous.map(describe).joined(separator: ", ")
    }

    /// Sets from the most recent *earlier* session of this same exercise (by definition),
    /// optionally filtered to one side. Used for the "last time" line and set pre-fill.
    private func previousSets(on side: SetSide?) -> [WorkoutSet] {
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

    private func describe(_ set: WorkoutSet) -> String {
        let sidePrefix = set.side.isEmpty ? "" : "\(set.side) "
        let load = set.weight.map { "\(format($0)) × " } ?? ""
        let core = exercise.isTimed
            ? "\(set.durationSeconds.map(String.init) ?? "—")s"
            : (set.reps.map(String.init) ?? "—")
        return sidePrefix + load + core
    }

    // MARK: - Mutation

    /// Append a set to the given side. Pre-fills from the matching set in the last
    /// session (set 2 copies last time's set 2), then the previous set in this one,
    /// and defaults RPE to the prescribed target — so a repeat session is mostly taps.
    private func addSet(side: SetSide?) {
        let sideSets = sets(on: side)
        let index = sideSets.count
        let priorForSide = previousSets(on: side)
        let template = priorForSide.indices.contains(index) ? priorForSide[index] : sideSets.last
        let newOrder = (sortedSets.map(\.order).max() ?? -1) + 1
        let newSet = WorkoutSet(
            reps: template?.reps,
            weight: template?.weight,
            durationSeconds: template?.durationSeconds,
            rpe: template?.rpe ?? exercise.targetRPE,
            side: side?.rawValue ?? "",
            order: newOrder
        )
        modelContext.insert(newSet)
        newSet.exercise = exercise
    }

    private func format(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
    }
}
