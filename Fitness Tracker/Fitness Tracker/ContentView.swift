internal import SwiftUI
import SwiftData

/// Root tab bar: Workouts (logging), Progress (charts), Plans (templates).
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
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(PersistenceController.preview.container)
}
