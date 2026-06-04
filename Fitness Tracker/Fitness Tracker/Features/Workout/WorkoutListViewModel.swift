import Foundation
import SwiftData

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
            // Unilateral exercises get a Left and a Right group.
            let sides = exercise.tracksSides ? ["L", "R"] : [""]
            var order = 0
            for side in sides {
                for _ in 0..<max(template.targetSets, 0) {
                    let set = WorkoutSet(rpe: template.targetRPEValue, side: side, order: order)
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
