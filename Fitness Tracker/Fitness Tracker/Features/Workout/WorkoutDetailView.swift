internal import SwiftUI
import SwiftData

/// One session being logged: editable date, each exercise as a row, and add-exercise.
/// Observes the `Workout` directly (single-model-edit pattern) so edits persist live.
struct WorkoutDetailView: View {
    @Bindable var workout: Workout
    @Environment(\.modelContext) private var modelContext
    @State private var showingExercisePicker = false

    private var sortedExercises: [Exercise] {
        (workout.exercises ?? []).sortedByOrder()
    }

    var body: some View {
        List {
            Section {
                DatePicker("Date", selection: $workout.date, displayedComponents: .date)
                if let plan = workout.trainingPlan {
                    LabeledContent("Plan", value: plan.name)
                }
            }

            ForEach(sortedExercises) { exercise in
                ExerciseRowView(exercise: exercise)
            }

            Section {
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
        .onDisappear(perform: trimEmptySets)
    }

    /// Remove pre-created sets that were never filled in, so an under-shot
    /// session doesn't leave empty 0×0 rows behind.
    private func trimEmptySets() {
        for exercise in workout.exercises ?? [] {
            for set in exercise.sets ?? [] where set.reps == nil && set.weight == nil && set.durationSeconds == nil {
                modelContext.delete(set)
            }
        }
    }

    private func addExercise(_ definition: ExerciseDefinition) {
        let exercise = Exercise(name: definition.name, order: workout.exercises?.count ?? 0)
        exercise.isTimed = definition.isTimed
        exercise.tracksSides = definition.tracksSides
        exercise.equipmentRaw = definition.equipmentRaw
        modelContext.insert(exercise)
        exercise.definition = definition
        exercise.workout = workout
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
