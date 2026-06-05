internal import SwiftUI
import SwiftData

/// The Workouts tab: lists past sessions, starts a new one from a plan, and
/// (debug only) generates sample history. Uses a ViewModel since it fetches a list.
struct WorkoutListView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = WorkoutListViewModel()
    @State private var showingPlanPicker = false
    @State private var activeWorkout: Workout?

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
                    for index in offsets {
                        viewModel.delete(viewModel.workouts[index], in: modelContext)
                    }
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
            .navigationDestination(item: $activeWorkout) { workout in
                WorkoutDetailView(workout: workout)
            }
        }
        .onAppear { viewModel.fetch(in: modelContext) }
    }
}

#Preview {
    WorkoutListView()
        .modelContainer(PersistenceController.preview.container)
}
