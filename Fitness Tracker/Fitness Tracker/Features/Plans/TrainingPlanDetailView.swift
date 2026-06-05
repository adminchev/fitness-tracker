internal import SwiftUI
import SwiftData

/// Edits one plan's prescribed exercises (add / delete / reorder). Observes the
/// `TrainingPlan` directly. Seeded exercises are protected from deletion.
struct TrainingPlanDetailView: View {
    @Bindable var plan: TrainingPlan
    @Environment(\.modelContext) private var modelContext
    @State private var showingExercisePicker = false

    private var sortedExercises: [TemplateExercise] {
        (plan.templateExercises ?? []).sortedByOrder()
    }

    var body: some View {
        List {
            if !plan.summary.isEmpty {
                Section {
                    Text(plan.summary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Exercises") {
                ForEach(sortedExercises) { exercise in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(exercise.name)
                            .font(.headline)
                        if !exercise.prescriptionSummary.isEmpty {
                            Text(exercise.prescriptionSummary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if !exercise.notes.isEmpty {
                            Text(exercise.notes)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, 2)
                    .deleteDisabled(exercise.isSeeded)
                }
                .onDelete(perform: deleteExercises)
                .onMove(perform: moveExercises)

                Button {
                    showingExercisePicker = true
                } label: {
                    Label("Add Exercise", systemImage: "plus.circle")
                }
            }
        }
        .navigationTitle(plan.name.isEmpty ? "Untitled Plan" : plan.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            EditButton()
        }
        .sheet(isPresented: $showingExercisePicker) {
            ExercisePickerView { definition in
                addExercise(definition)
            }
        }
    }

    private func addExercise(_ definition: ExerciseDefinition) {
        let exercise = TemplateExercise(name: definition.name, order: plan.templateExercises?.count ?? 0)
        modelContext.insert(exercise)
        exercise.definition = definition
        exercise.plan = plan
    }

    private func deleteExercises(at offsets: IndexSet) {
        for index in offsets where !sortedExercises[index].isSeeded {
            modelContext.delete(sortedExercises[index])
        }
    }

    private func moveExercises(from source: IndexSet, to destination: Int) {
        var reordered = sortedExercises
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, exercise) in reordered.enumerated() {
            exercise.order = index
        }
    }
}

#Preview {
    let container = PersistenceController.preview.container
    let plan = TrainingPlan(name: "Push Day")
    container.mainContext.insert(plan)
    return NavigationStack {
        TrainingPlanDetailView(plan: plan)
    }
    .modelContainer(container)
}
