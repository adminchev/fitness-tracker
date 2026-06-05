import Foundation
import SwiftData

/// Backs `TrainingPlansView`: fetches, creates, and deletes plans.
@Observable final class TrainingPlansViewModel {
    var plans: [TrainingPlan] = []

    func fetch(in context: ModelContext) {
        let descriptor = FetchDescriptor<TrainingPlan>(sortBy: [SortDescriptor(\.order)])
        plans = (try? context.fetch(descriptor)) ?? []
    }

    func addPlan(name: String, in context: ModelContext) {
        let plan = TrainingPlan(name: name, order: plans.count)
        context.insert(plan)
        fetch(in: context)
    }

    func deletePlan(_ plan: TrainingPlan, in context: ModelContext) {
        context.delete(plan)
        fetch(in: context)
    }
}
