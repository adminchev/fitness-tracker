import Foundation
import SwiftData

// MARK: - File format
//
// Plain Codable DTOs that mirror the @Model graph, kept deliberately separate from
// the SwiftData classes so the on-disk format stays stable as the models evolve.
// Ownership is nested (workout → exercises → sets; plan → template exercises) and
// cross-references go by name (`definitionName`, `planName`), so a restore can
// rebuild every relationship without needing stable UUIDs on the models.

struct BackupFile: Codable {
    var schemaVersion: Int
    var exportedAt: Date
    var definitions: [DefinitionDTO]
    var plans: [PlanDTO]
    var workouts: [WorkoutDTO]

    static let currentVersion = 1
}

struct DefinitionDTO: Codable {
    var name: String
    var equipment: String
    var isTimed: Bool
    var tracksSides: Bool
    var isSeeded: Bool
}

struct PlanDTO: Codable {
    var name: String
    var order: Int
    var summary: String
    var isSeeded: Bool
    var exercises: [TemplateExerciseDTO]
}

struct TemplateExerciseDTO: Codable {
    var name: String
    var definitionName: String?
    var order: Int
    var targetSets: Int
    var targetReps: String
    var targetRPE: String
    var restSeconds: Int
    var notes: String
    var isSeeded: Bool
}

struct WorkoutDTO: Codable {
    var date: Date
    var name: String
    var notes: String
    var planName: String?
    var exercises: [ExerciseDTO]
}

struct ExerciseDTO: Codable {
    var name: String
    var definitionName: String?
    var order: Int
    var targetSummary: String
    var notes: String
    var isTimed: Bool
    var tracksSides: Bool
    var equipment: String
    var targetRPE: Double?
    var sets: [SetDTO]
}

struct SetDTO: Codable {
    var reps: Int?
    var weight: Double?
    var durationSeconds: Int?
    var rpe: Double?
    var side: String
    var order: Int
}

// MARK: - Export / Restore

/// Serialises the whole store to a `BackupFile` and rebuilds it on restore.
/// Restore is **replace-everything**: it wipes the store, then recreates the graph.
@MainActor
enum BackupService {

    static func export(_ context: ModelContext) throws -> Data {
        let definitions = try context.fetch(FetchDescriptor<ExerciseDefinition>(sortBy: [SortDescriptor(\.name)]))
            .map { definition in
                DefinitionDTO(name: definition.name, equipment: definition.equipmentRaw,
                              isTimed: definition.isTimed, tracksSides: definition.tracksSides,
                              isSeeded: definition.isSeeded)
            }

        let plans = try context.fetch(FetchDescriptor<TrainingPlan>(sortBy: [SortDescriptor(\.order)]))
            .map { plan in
                PlanDTO(name: plan.name, order: plan.order, summary: plan.summary, isSeeded: plan.isSeeded,
                        exercises: (plan.templateExercises ?? []).sortedByOrder().map { template in
                            TemplateExerciseDTO(name: template.name, definitionName: template.definition?.name,
                                                order: template.order, targetSets: template.targetSets,
                                                targetReps: template.targetReps, targetRPE: template.targetRPE,
                                                restSeconds: template.restSeconds, notes: template.notes,
                                                isSeeded: template.isSeeded)
                        })
            }

        let workouts = try context.fetch(FetchDescriptor<Workout>(sortBy: [SortDescriptor(\.date)]))
            .map { workout in
                WorkoutDTO(date: workout.date, name: workout.name, notes: workout.notes,
                           planName: workout.trainingPlan?.name,
                           exercises: (workout.exercises ?? []).sortedByOrder().map { exercise in
                               ExerciseDTO(name: exercise.name, definitionName: exercise.definition?.name,
                                           order: exercise.order, targetSummary: exercise.targetSummary,
                                           notes: exercise.notes, isTimed: exercise.isTimed,
                                           tracksSides: exercise.tracksSides, equipment: exercise.equipmentRaw,
                                           targetRPE: exercise.targetRPE,
                                           sets: (exercise.sets ?? []).sortedByOrder().map { set in
                                               SetDTO(reps: set.reps, weight: set.weight,
                                                      durationSeconds: set.durationSeconds, rpe: set.rpe,
                                                      side: set.side, order: set.order)
                                           })
                           })
            }

        let file = BackupFile(schemaVersion: BackupFile.currentVersion, exportedAt: Date(),
                              definitions: definitions, plans: plans, workouts: workouts)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(file)
    }

    static func restore(from data: Data, into context: ModelContext) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let file = try decoder.decode(BackupFile.self, from: data)

        // Wipe everything (workout delete cascades to exercises + sets; plan to templates).
        try context.delete(model: Workout.self)
        try context.delete(model: TrainingPlan.self)
        try context.delete(model: ExerciseDefinition.self)

        // 1) Definitions, indexed by name for linking.
        var definitionsByName: [String: ExerciseDefinition] = [:]
        for dto in file.definitions {
            let definition = ExerciseDefinition(name: dto.name)
            definition.equipmentRaw = dto.equipment
            definition.isTimed = dto.isTimed
            definition.tracksSides = dto.tracksSides
            definition.isSeeded = dto.isSeeded
            context.insert(definition)
            definitionsByName[dto.name] = definition
        }

        // 2) Plans + their prescribed exercises.
        var plansByName: [String: TrainingPlan] = [:]
        for dto in file.plans {
            let plan = TrainingPlan(name: dto.name, order: dto.order, summary: dto.summary)
            plan.isSeeded = dto.isSeeded
            context.insert(plan)
            plansByName[dto.name] = plan
            for template in dto.exercises {
                let exercise = TemplateExercise(name: template.name, order: template.order,
                                                targetSets: template.targetSets, targetReps: template.targetReps,
                                                targetRPE: template.targetRPE, restSeconds: template.restSeconds,
                                                notes: template.notes)
                exercise.isSeeded = template.isSeeded
                context.insert(exercise)
                exercise.plan = plan
                exercise.definition = template.definitionName.flatMap { definitionsByName[$0] }
            }
        }

        // 3) Workouts + exercises + sets.
        for dto in file.workouts {
            let workout = Workout(name: dto.name, date: dto.date, notes: dto.notes)
            workout.trainingPlan = dto.planName.flatMap { plansByName[$0] }
            context.insert(workout)
            for exerciseDTO in dto.exercises {
                let exercise = Exercise(name: exerciseDTO.name, order: exerciseDTO.order,
                                        targetSummary: exerciseDTO.targetSummary, notes: exerciseDTO.notes)
                exercise.isTimed = exerciseDTO.isTimed
                exercise.tracksSides = exerciseDTO.tracksSides
                exercise.equipmentRaw = exerciseDTO.equipment
                exercise.targetRPE = exerciseDTO.targetRPE
                context.insert(exercise)
                exercise.workout = workout
                exercise.definition = exerciseDTO.definitionName.flatMap { definitionsByName[$0] }
                for setDTO in exerciseDTO.sets {
                    let set = WorkoutSet(reps: setDTO.reps, weight: setDTO.weight,
                                         durationSeconds: setDTO.durationSeconds, rpe: setDTO.rpe,
                                         side: setDTO.side, order: setDTO.order)
                    context.insert(set)
                    set.exercise = exercise
                }
            }
        }

        try context.save()
    }
}
