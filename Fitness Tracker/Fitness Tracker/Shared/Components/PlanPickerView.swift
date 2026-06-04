internal import SwiftUI
import SwiftData

struct PlanPickerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var plans: [TrainingPlan] = []
    let onSelect: (TrainingPlan) -> Void

    var body: some View {
        NavigationStack {
            List {
                if plans.isEmpty {
                    ContentUnavailableView(
                        "No Plans Yet",
                        systemImage: "list.clipboard",
                        description: Text("Create a training plan in the Plans tab first.")
                    )
                }
                ForEach(plans) { plan in
                    Button(plan.name.isEmpty ? "Untitled Plan" : plan.name) {
                        onSelect(plan)
                        dismiss()
                    }
                    .foregroundStyle(.primary)
                }
            }
            .navigationTitle("Choose a Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear {
            let descriptor = FetchDescriptor<TrainingPlan>(sortBy: [SortDescriptor(\.order)])
            plans = (try? modelContext.fetch(descriptor)) ?? []
        }
    }
}
