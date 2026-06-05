internal import SwiftUI
import SwiftData

/// The Plans tab: lists training plans and creates new ones. Seeded plans show a
/// lock and can't be deleted.
struct TrainingPlansView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = TrainingPlansViewModel()
    @State private var showingAddPlan = false
    @State private var newPlanName = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.plans) { plan in
                    NavigationLink(destination: TrainingPlanDetailView(plan: plan)) {
                        HStack {
                            Text(plan.name.isEmpty ? "Untitled Plan" : plan.name)
                            if plan.isSeeded {
                                Spacer()
                                Image(systemName: "lock.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .deleteDisabled(plan.isSeeded)
                }
                .onDelete { offsets in
                    for index in offsets {
                        viewModel.deletePlan(viewModel.plans[index], in: modelContext)
                    }
                }
            }
            .navigationTitle("Training Plans")
            .overlay {
                if viewModel.plans.isEmpty {
                    ContentUnavailableView(
                        "No Plans",
                        systemImage: "list.clipboard",
                        description: Text("Tap + to create your first training plan.")
                    )
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingAddPlan = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("New Plan", isPresented: $showingAddPlan) {
                TextField("e.g. Push Day", text: $newPlanName)
                Button("Create") {
                    viewModel.addPlan(name: newPlanName, in: modelContext)
                    newPlanName = ""
                }
                Button("Cancel", role: .cancel) { newPlanName = "" }
            }
        }
        .onAppear { viewModel.fetch(in: modelContext) }
    }
}

#Preview {
    TrainingPlansView()
        .modelContainer(PersistenceController.preview.container)
}
