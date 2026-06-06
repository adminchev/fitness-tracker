internal import SwiftUI
import SwiftData

/// Full-screen, one-exercise-at-a-time logger. Opened by tapping an exercise in the
/// workout overview. Swipe horizontally to move between the session's exercises;
/// the nav back button (or edge-swipe) returns to the overview list.
struct ExerciseFocusView: View {
    let workout: Workout
    @State private var selection: PersistentIdentifier?

    init(workout: Workout, startExerciseID: PersistentIdentifier? = nil) {
        self.workout = workout
        _selection = State(initialValue: startExerciseID)
    }

    private var exercises: [Exercise] {
        (workout.exercises ?? []).sortedByOrder()
    }

    var body: some View {
        TabView(selection: $selection) {
            ForEach(Array(exercises.enumerated()), id: \.element.persistentModelID) { index, exercise in
                FocusedExercisePage(exercise: exercise, position: index + 1, total: exercises.count)
                    .tag(Optional(exercise.persistentModelID))
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .navigationTitle(currentName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var currentName: String {
        exercises.first { $0.persistentModelID == selection }?.name ?? "Workout"
    }
}

/// One exercise's focused logging page: a Left/Right tab (if unilateral), that side's
/// sets with big controls, and Add Set / Copy buttons sized for use mid-workout.
private struct FocusedExercisePage: View {
    @Bindable var exercise: Exercise
    let position: Int
    let total: Int
    @Environment(\.modelContext) private var modelContext
    @State private var selectedSide: SetSide = AppSettings.leadSide

    /// Lead arm first, so the leftmost tab matches the user's "start with" preference.
    private var orderedSides: [SetSide] {
        let lead = AppSettings.leadSide
        return [lead, lead.opposite]
    }

    private var sortedSets: [WorkoutSet] {
        (exercise.sets ?? []).sortedByOrder()
    }

    /// Sets for the active context: the selected side, or all sets when bilateral.
    private var visibleSets: [WorkoutSet] {
        exercise.tracksSides ? sets(on: selectedSide) : sortedSets
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                if exercise.tracksSides {
                    Picker("Side", selection: $selectedSide) {
                        ForEach(orderedSides) { side in
                            Text(side == .left ? "Left" : "Right").tag(side)
                        }
                    }
                    .pickerStyle(.segmented)
                    .controlSize(.large)
                }

                VStack(spacing: 10) {
                    ForEach(Array(visibleSets.enumerated()), id: \.element.persistentModelID) { index, set in
                        HStack(spacing: 12) {
                            SetRowView(
                                set: set,
                                setNumber: index + 1,
                                isTimed: exercise.isTimed,
                                equipment: exercise.equipment,
                                weightSuggestions: weightSuggestions(forIndex: index),
                                repSuggestions: repSuggestions(forIndex: index)
                            )
                            Button(role: .destructive) {
                                modelContext.delete(set)
                            } label: {
                                Image(systemName: "minus.circle.fill").font(.title3)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }

                Button {
                    addSet()
                } label: {
                    Label("Add Set", systemImage: "plus.circle.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                if exercise.tracksSides {
                    Button {
                        copyToOtherSide()
                    } label: {
                        Label("Copy \(selectedSide == .left ? "L → R" : "R → L")", systemImage: "arrow.left.arrow.right")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }

                if !exercise.notes.isEmpty {
                    Text(exercise.notes)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
            }
            .padding()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Exercise \(position) of \(total)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            if !exercise.targetSummary.isEmpty {
                Text(exercise.targetSummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let lastTimeSummary {
                Text(lastTimeSummary)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Data helpers

    private func sets(on side: SetSide?) -> [WorkoutSet] {
        sortedSets.filter { $0.side == (side?.rawValue ?? "") }
    }

    private var activeSide: SetSide? {
        exercise.tracksSides ? selectedSide : nil
    }

    /// Weight chips for a set: last session's matching weight ± the equipment's load
    /// step (so bands suggest ±1, plates ±2.5 — matching the steppers).
    private func weightSuggestions(forIndex index: Int) -> [Double] {
        let prior = previousSets(on: activeSide)
        let base = prior.indices.contains(index) ? prior[index].weight : sets(on: activeSide).last?.weight
        let step = exercise.equipment.loadStep
        guard let base, base > 0, step > 0 else { return [] }
        let candidates = [base - 2 * step, base - step, base, base + step, base + 2 * step]
        return Array(Set(candidates.filter { $0 > 0 })).sorted()
    }

    /// Rep chips for a set: last session's matching reps ± a couple.
    private func repSuggestions(forIndex index: Int) -> [Double] {
        let prior = previousSets(on: activeSide)
        let base = prior.indices.contains(index) ? prior[index].reps : sets(on: activeSide).last?.reps
        guard let base, base > 0 else { return [] }
        return Array(Set([base - 2, base - 1, base, base + 1, base + 2].filter { $0 > 0 })).sorted().map(Double.init)
    }

    private var lastTimeSummary: String? {
        let previous = previousSets(on: nil)
        guard !previous.isEmpty else { return nil }
        return "Last: " + previous.map(describe).joined(separator: ", ")
    }

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

    private func addSet() {
        let side: SetSide? = exercise.tracksSides ? selectedSide : nil
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

    /// Mirror the visible side's sets onto the other arm (replacing whatever was there).
    private func copyToOtherSide() {
        guard exercise.tracksSides else { return }
        let source = sets(on: selectedSide)
        let other = selectedSide.opposite
        sets(on: other).forEach { modelContext.delete($0) }
        var order = (sortedSets.map(\.order).max() ?? -1) + 1
        for set in source {
            let copy = WorkoutSet(reps: set.reps, weight: set.weight, durationSeconds: set.durationSeconds, rpe: set.rpe, side: other.rawValue, order: order)
            order += 1
            modelContext.insert(copy)
            copy.exercise = exercise
        }
    }

    private func format(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
    }
}
