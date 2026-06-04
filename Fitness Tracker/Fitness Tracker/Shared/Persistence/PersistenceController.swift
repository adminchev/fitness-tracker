import Foundation
import SwiftData

/// Owns the SwiftData `ModelContainer`. `shared` is the live, CloudKit-synced store;
/// `preview` is an in-memory store for SwiftUI previews. Seeds the catalog + plans
/// on first launch (when the store is empty).
@MainActor
struct PersistenceController {
    static let shared = PersistenceController()
    static let preview = PersistenceController(inMemory: true)

    let container: ModelContainer

    init(inMemory: Bool = false) {
        let schema = Schema([
            Workout.self,
            Exercise.self,
            WorkoutSet.self,
            TrainingPlan.self,
            TemplateExercise.self,
            ExerciseDefinition.self,
        ])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: inMemory ? .none : .automatic
        )
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
        SeedData.seedIfNeeded(container.mainContext)
    }
}
