internal import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            WorkoutListView()
                .tabItem {
                    Label("Workouts", systemImage: "dumbbell")
                }
            ProgressDashboardView()
                .tabItem {
                    Label("Progress", systemImage: "chart.line.uptrend.xyaxis")
                }
            TrainingPlansView()
                .tabItem {
                    Label("Plans", systemImage: "list.clipboard")
                }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(PersistenceController.preview.container)
}
