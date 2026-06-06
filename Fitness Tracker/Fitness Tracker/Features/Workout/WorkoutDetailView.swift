internal import SwiftUI
import SwiftData

/// Overview of one session: editable date, a tappable list of its exercises (each
/// opens the focused logger), and add-exercise. Observes the `Workout` directly.
struct WorkoutDetailView: View {
    @Bindable var workout: Workout
    @Environment(\.modelContext) private var modelContext
    @State private var showingExercisePicker = false
    @State private var showingDatePicker = false

    private var sortedExercises: [Exercise] {
        (workout.exercises ?? []).sortedByOrder()
    }

    var body: some View {
        List {
            Section {
                // Present the calendar as a modal sheet rather than the inline
                // popover — the popover lets a dismissing tap fall through to the
                // buttons behind it; a sheet blocks the background while it's open.
                Button {
                    showingDatePicker = true
                } label: {
                    LabeledContent("Date") {
                        Text(workout.date.formatted(date: .abbreviated, time: .omitted))
                            .foregroundStyle(Color.accentColor)
                    }
                }
                .buttonStyle(.plain)
                if let plan = workout.trainingPlan {
                    LabeledContent("Plan", value: plan.name)
                }
            }

            Section("Exercises") {
                ForEach(sortedExercises) { exercise in
                    NavigationLink {
                        ExerciseFocusView(workout: workout, startExerciseID: exercise.persistentModelID)
                    } label: {
                        exerciseRow(exercise)
                    }
                }

                Button {
                    showingExercisePicker = true
                } label: {
                    Label("Add Exercise", systemImage: "plus.circle")
                }
            }
        }
        .navigationTitle(workout.name.isEmpty ? "Workout" : workout.name)
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showingExercisePicker) {
            ExercisePickerView { definition in
                addExercise(definition)
            }
        }
        .sheet(isPresented: $showingDatePicker) {
            NavigationStack {
                DatePicker("Date", selection: $workout.date, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding(.horizontal)
                    .navigationTitle("Workout Date")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showingDatePicker = false }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
        }
        .onDisappear(perform: trimEmptySets)
    }

    private func exerciseRow(_ exercise: Exercise) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(exercise.name)
                .font(.headline)
            Text(summary(for: exercise))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func summary(for exercise: Exercise) -> String {
        let sets = exercise.sets ?? []
        let logged = sets.filter { $0.reps != nil || $0.weight != nil || $0.durationSeconds != nil }.count
        if !exercise.targetSummary.isEmpty {
            return logged > 0 ? "\(exercise.targetSummary)  ·  \(logged) logged" : exercise.targetSummary
        }
        return logged > 0 ? "\(logged) sets logged" : "Tap to log"
    }

    private func addExercise(_ definition: ExerciseDefinition) {
        let exercise = Exercise(name: definition.name, order: workout.exercises?.count ?? 0)
        exercise.isTimed = definition.isTimed
        exercise.tracksSides = definition.tracksSides
        exercise.equipmentRaw = definition.equipmentRaw
        modelContext.insert(exercise)
        exercise.definition = definition
        exercise.workout = workout
        // Open one set straight away so the exercise is ready to log — both arms if unilateral.
        let lead = AppSettings.leadSide
        let sides: [SetSide?] = exercise.tracksSides ? [lead, lead.opposite] : [nil]
        for (order, side) in sides.enumerated() {
            let set = WorkoutSet(side: side?.rawValue ?? "", order: order)
            modelContext.insert(set)
            set.exercise = exercise
        }
    }

    /// Remove leftover empty sets — but only in exercises you actually started, so an
    /// untouched exercise keeps its prescribed (pre-created) sets for next time.
    private func trimEmptySets() {
        for exercise in workout.exercises ?? [] {
            let sets = exercise.sets ?? []
            let started = sets.contains { $0.reps != nil || $0.weight != nil || $0.durationSeconds != nil }
            guard started else { continue }
            for set in sets where set.reps == nil && set.weight == nil && set.durationSeconds == nil {
                modelContext.delete(set)
            }
        }
    }
}

#Preview {
    let container = PersistenceController.preview.container
    let workout = Workout(name: "Push Day")
    container.mainContext.insert(workout)
    let exercise = Exercise(name: "Bench Press", order: 0)
    container.mainContext.insert(exercise)
    workout.exercises = [exercise]
    return NavigationStack {
        WorkoutDetailView(workout: workout)
    }
    .modelContainer(container)
}
