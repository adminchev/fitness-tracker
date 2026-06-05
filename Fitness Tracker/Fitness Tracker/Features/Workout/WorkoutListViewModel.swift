import Foundation
import SwiftData

/// Backs `WorkoutListView`: fetches sessions, expands a plan into a new workout
/// (pre-creating both arms' sets + RPE for unilateral exercises), and deletes.
@Observable final class WorkoutListViewModel {
    var workouts: [Workout] = []
    var errorMessage: String?

    func fetch(in context: ModelContext) {
        let descriptor = FetchDescriptor<Workout>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        do {
            workouts = try context.fetch(descriptor)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createWorkout(from plan: TrainingPlan, in context: ModelContext) -> Workout {
        let workout = Workout(name: plan.name)
        workout.trainingPlan = plan
        context.insert(workout)
        let templates = (plan.templateExercises ?? []).sortedByOrder()
        for (index, template) in templates.enumerated() {
            let exercise = Exercise(
                name: template.name,
                order: index,
                targetSummary: template.prescriptionSummary,
                notes: template.notes
            )
            exercise.isTimed = template.definition?.isTimed ?? false
            exercise.tracksSides = template.definition?.tracksSides ?? false
            exercise.equipmentRaw = template.definition?.equipmentRaw ?? Equipment.freeWeight.rawValue
            exercise.targetRPE = template.targetRPEValue
            context.insert(exercise)
            exercise.definition = template.definition
            exercise.workout = workout
            // Pre-create the prescribed sets, RPE pre-filled to the target.
            // Unilateral exercises get both arms, lead arm first.
            let lead = AppSettings.leadSide
            let sides: [SetSide?] = exercise.tracksSides ? [lead, lead.opposite] : [nil]
            var order = 0
            for side in sides {
                for _ in 0..<max(template.targetSets, 0) {
                    let set = WorkoutSet(rpe: template.targetRPEValue, side: side?.rawValue ?? "", order: order)
                    order += 1
                    context.insert(set)
                    set.exercise = exercise
                }
            }
        }
        fetch(in: context)
        return workout
    }

    func delete(_ workout: Workout, in context: ModelContext) {
        context.delete(workout)
        fetch(in: context)
    }

    func clearAllWorkouts(in context: ModelContext) {
        for workout in (try? context.fetch(FetchDescriptor<Workout>())) ?? [] {
            context.delete(workout)
        }
        fetch(in: context)
    }
}
