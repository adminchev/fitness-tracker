internal import SwiftUI
import SwiftData

/// The Workouts tab: lists past sessions, starts a new one from a plan, and
/// (debug only) generates sample history. Uses a ViewModel since it fetches a list.
struct WorkoutListView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = WorkoutListViewModel()
    @State private var showingPlanPicker = false
    @State private var activeWorkout: Workout?
    @State private var workoutToDelete: Workout?

    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.workouts) { workout in
                    NavigationLink(destination: WorkoutDetailView(workout: workout)) {
                        VStack(alignment: .leading) {
                            Text(workout.name.isEmpty ? "Untitled Workout" : workout.name)
                                .font(.headline)
                            Text(workout.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { offsets in
                    // Confirm before deleting — sessions can't be recovered.
                    workoutToDelete = offsets.first.map { viewModel.workouts[$0] }
                }
            }
            .navigationTitle("Workouts")
            .overlay {
                if viewModel.workouts.isEmpty {
                    ContentUnavailableView(
                        "No Workouts Yet",
                        systemImage: "dumbbell",
                        description: Text("Tap + to start a workout from a training plan.")
                    )
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingPlanPicker = true } label: {
                        Image(systemName: "plus")
                    }
                }
                #if DEBUG
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("Load sample history") {
                            SampleData.generate(modelContext)
                            viewModel.fetch(in: modelContext)
                        }
                        Button("Clear all workouts", role: .destructive) {
                            viewModel.clearAllWorkouts(in: modelContext)
                        }
                    } label: {
                        Image(systemName: "ladybug")
                    }
                }
                #endif
            }
            .sheet(isPresented: $showingPlanPicker) {
                PlanPickerView { plan in
                    activeWorkout = viewModel.createWorkout(from: plan, in: modelContext)
                }
            }
            .alert(
                "Delete this workout?",
                isPresented: Binding(get: { workoutToDelete != nil }, set: { if !$0 { workoutToDelete = nil } }),
                presenting: workoutToDelete
            ) { workout in
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    viewModel.delete(workout, in: modelContext)
                }
            } message: { workout in
                let name = workout.name.isEmpty ? "Untitled Workout" : workout.name
                let date = workout.date.formatted(date: .abbreviated, time: .omitted)
                Text("\(name) — \(date)\nThis session and its logged sets will be permanently removed.")
            }
            .navigationDestination(item: $activeWorkout) { workout in
                WorkoutDetailView(workout: workout)
            }
            // On the List (not the NavigationStack) so it re-runs on pop-back —
            // re-sorting after a session's date is edited in the detail view.
            .onAppear { viewModel.fetch(in: modelContext) }
        }
    }
}

#Preview {
    WorkoutListView()
        .modelContainer(PersistenceController.preview.container)
}
