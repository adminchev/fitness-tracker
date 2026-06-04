internal import SwiftUI
import SwiftData

struct ExerciseRowView: View {
    @Bindable var exercise: Exercise
    @Environment(\.modelContext) private var modelContext
    @State private var selectedSide: String = "L"

    private var sortedSets: [WorkoutSet] {
        (exercise.sets ?? []).sortedByOrder()
    }

    private func sets(forSide side: String) -> [WorkoutSet] {
        sortedSets.filter { $0.side == side }
    }

    private var lastTimeSummary: String? {
        let previous = previousSets(forSide: "")
        guard !previous.isEmpty else { return nil }
        return "Last: " + previous.map(describe).joined(separator: ", ")
    }

    var body: some View {
        Section {
            if exercise.tracksSides {
                Picker("Side", selection: $selectedSide) {
                    Text("Left").tag("L")
                    Text("Right").tag("R")
                }
                .pickerStyle(.segmented)
                setRows(sets(forSide: selectedSide))
                addButton("Add Set", side: selectedSide)
            } else {
                setRows(sets(forSide: ""))
                addButton("Add Set", side: "")
            }
        } header: {
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(.headline)
                    .textCase(nil)
                if !exercise.targetSummary.isEmpty {
                    Text(exercise.targetSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }
                if let lastTimeSummary {
                    Text(lastTimeSummary)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .textCase(nil)
                }
            }
        } footer: {
            if !exercise.notes.isEmpty {
                Text(exercise.notes).textCase(nil)
            }
        }
    }

    @ViewBuilder private func setRows(_ groupSets: [WorkoutSet]) -> some View {
        ForEach(Array(groupSets.enumerated()), id: \.element.persistentModelID) { index, set in
            SetRowView(set: set, setNumber: index + 1, isTimed: exercise.isTimed, equipment: exercise.equipment)
        }
        .onDelete { offsets in
            for index in offsets { modelContext.delete(groupSets[index]) }
        }
    }

    private func addButton(_ title: String, side: String) -> some View {
        Button {
            addSet(side: side)
        } label: {
            Label(title, systemImage: "plus.circle.fill")
                .font(.subheadline.bold())
        }
        .buttonStyle(.borderless)
    }

    /// Sets from the most recent earlier session of this exercise, optionally filtered to a side.
    private func previousSets(forSide side: String) -> [WorkoutSet] {
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
        return side.isEmpty ? sets : sets.filter { $0.side == side }
    }

    private func describe(_ set: WorkoutSet) -> String {
        let sidePrefix = set.side.isEmpty ? "" : "\(set.side) "
        let load = set.weight.map { "\(format($0)) × " } ?? ""
        let core = exercise.isTimed
            ? "\(set.durationSeconds.map(String.init) ?? "—")s"
            : (set.reps.map(String.init) ?? "—")
        return sidePrefix + load + core
    }

    private func addSet(side: String) {
        let sideSets = sets(forSide: side)
        let index = sideSets.count
        let priorForSide = previousSets(forSide: side)
        let template = priorForSide.indices.contains(index) ? priorForSide[index] : sideSets.last
        let newOrder = (sortedSets.map(\.order).max() ?? -1) + 1
        let newSet = WorkoutSet(
            reps: template?.reps,
            weight: template?.weight,
            durationSeconds: template?.durationSeconds,
            rpe: template?.rpe ?? exercise.targetRPE,
            side: side,
            order: newOrder
        )
        modelContext.insert(newSet)
        newSet.exercise = exercise
    }

    private func format(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
    }
}
