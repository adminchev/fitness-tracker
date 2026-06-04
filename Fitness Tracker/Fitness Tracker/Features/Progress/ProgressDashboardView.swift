internal import SwiftUI
import SwiftData
import Charts

struct ProgressDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = ProgressDashboardViewModel()
    @State private var consistencyRange: ConsistencyRange = .threeMonths

    var body: some View {
        NavigationStack {
            List {
                Section("Consistency") {
                    HStack {
                        stat("This week", viewModel.workoutsThisWeek())
                        Divider()
                        stat("This month", viewModel.workoutsThisMonth())
                        Divider()
                        stat("Total", viewModel.totalWorkouts)
                    }
                    .frame(maxWidth: .infinity)

                    Picker("Window", selection: $consistencyRange) {
                        ForEach(ConsistencyRange.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    Chart(viewModel.bars(for: consistencyRange)) { bar in
                        if consistencyRange == .twoWeeks {
                            if bar.count > 0 {
                                PointMark(
                                    x: .value("Day", bar.start, unit: .day),
                                    y: .value("Workouts", bar.count)
                                )
                                .foregroundStyle(Color.accentColor)
                                .symbolSize(130)
                            }
                        } else {
                            BarMark(
                                x: .value("Date", bar.start, unit: consistencyRange.bucketUnit),
                                y: .value("Workouts", bar.count)
                            )
                            .foregroundStyle(Color.accentColor.gradient)
                            .cornerRadius(4)
                        }
                    }
                    .chartXAxis {
                        if consistencyRange == .twoWeeks {
                            AxisMarks(values: .stride(by: .day, count: 2)) {
                                AxisGridLine().foregroundStyle(Color.secondary.opacity(0.12))
                                AxisValueLabel(format: .dateTime.day())
                            }
                        } else {
                            AxisMarks(values: .automatic(desiredCount: 5))
                        }
                    }
                    .frame(height: 160)
                    .padding(.vertical, 4)
                    .animation(.easeInOut(duration: 0.25), value: consistencyRange)

                    if let recovery = viewModel.averageRecoveryDays(in: consistencyRange) {
                        LabeledContent("Avg recovery", value: String(format: "%.1f days", recovery))
                    }
                }

                Section("Exercises") {
                    if viewModel.trainedDefinitions.isEmpty {
                        Text("Log a workout to start tracking progress.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(viewModel.trainedDefinitions) { definition in
                        NavigationLink(definition.name) {
                            ExerciseProgressView(definition: definition)
                        }
                    }
                }
            }
            .navigationTitle("Progress")
        }
        .onAppear { viewModel.load(in: modelContext) }
    }

    private func stat(_ label: String, _ value: Int) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.title2.bold())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ProgressDashboardView()
        .modelContainer(PersistenceController.preview.container)
}
