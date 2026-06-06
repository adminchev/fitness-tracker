internal import SwiftUI
import SwiftData

/// Full-screen logger opened by tapping an exercise in the workout overview.
/// Standard mode is a swipeable page per exercise; Accessible mode shows the single
/// tapped exercise's guided stepper flow (no inter-exercise swipe). The layout comes
/// from Settings and can be flipped any time.
struct ExerciseFocusView: View {
    let workout: Workout
    @State private var selection: PersistentIdentifier?
    @AppStorage(AppSettings.logLayoutKey) private var layoutRaw = LogLayout.standard.rawValue

    init(workout: Workout, startExerciseID: PersistentIdentifier? = nil) {
        self.workout = workout
        _selection = State(initialValue: startExerciseID)
    }

    private var layout: LogLayout { LogLayout(rawValue: layoutRaw) ?? .standard }

    private var exercises: [Exercise] {
        (workout.exercises ?? []).sortedByOrder()
    }

    private var currentExercise: Exercise? {
        exercises.first { $0.persistentModelID == selection } ?? exercises.first
    }

    var body: some View {
        switch layout {
        case .accessible:
            if let exercise = currentExercise {
                GuidedLoggerView(exercise: exercise)
            } else {
                ContentUnavailableView("No exercises", systemImage: "dumbbell")
            }
        case .standard:
            standardPager
        }
    }

    private var standardPager: some View {
        TabView(selection: $selection) {
            ForEach(Array(exercises.enumerated()), id: \.element.persistentModelID) { index, exercise in
                FocusedExercisePage(exercise: exercise, position: index + 1, total: exercises.count)
                    .tag(Optional(exercise.persistentModelID))
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .navigationTitle(currentExercise?.name ?? "Workout")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// One exercise's focused logging page (Standard mode): a Left/Right tab (if unilateral),
/// that side's sets with the compact controls, and Add Set / Copy buttons.
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
                            CompactSetRow(
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
        let prior = PreviousSession.sets(for: exercise, on: activeSide)
        let base = prior.indices.contains(index) ? prior[index].weight : sets(on: activeSide).last?.weight
        let step = exercise.equipment.loadStep
        guard let base, base > 0, step > 0 else { return [] }
        let candidates = [base - 2 * step, base - step, base, base + step, base + 2 * step]
        return Array(Set(candidates.filter { $0 > 0 })).sorted()
    }

    /// Rep chips for a set: last session's matching reps ± a couple.
    private func repSuggestions(forIndex index: Int) -> [Double] {
        let prior = PreviousSession.sets(for: exercise, on: activeSide)
        let base = prior.indices.contains(index) ? prior[index].reps : sets(on: activeSide).last?.reps
        guard let base, base > 0 else { return [] }
        return Array(Set([base - 2, base - 1, base, base + 1, base + 2].filter { $0 > 0 })).sorted().map(Double.init)
    }

    private var lastTimeSummary: String? {
        let previous = PreviousSession.sets(for: exercise)
        guard !previous.isEmpty else { return nil }
        return "Last: " + previous.map { PreviousSession.describe($0, isTimed: exercise.isTimed) }.joined(separator: ", ")
    }

    // MARK: - Mutation

    private func addSet() {
        let side: SetSide? = exercise.tracksSides ? selectedSide : nil
        let sideSets = sets(on: side)
        let index = sideSets.count
        let priorForSide = PreviousSession.sets(for: exercise, on: side)
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
}
