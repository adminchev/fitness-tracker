import Testing
import Foundation
import SwiftData
import SwiftUI
@testable import Fitness_Tracker

@MainActor
struct ProgressCalculatorTests {

    // MARK: - sessionValue / single-set math

    @Test func epleyOneRepMax() {
        let set = WorkoutSet(reps: 5, weight: 100)
        #expect(abs(ProgressCalculator.oneRepMax(set) - 116.6667) < 0.01)
    }

    @Test func oneRepMaxIsZeroWithoutData() {
        #expect(ProgressCalculator.oneRepMax(WorkoutSet(reps: 0, weight: 100)) == 0)
        #expect(ProgressCalculator.oneRepMax(WorkoutSet(reps: 5, weight: nil)) == 0)
        #expect(ProgressCalculator.oneRepMax(WorkoutSet()) == 0)
    }

    @Test func topWeightTakesMaxAndIgnoresNil() {
        let sets = [WorkoutSet(weight: 40), WorkoutSet(weight: 47.5), WorkoutSet(weight: nil)]
        #expect(ProgressCalculator.sessionValue(sets, metric: .topWeight) == 47.5)
    }

    @Test func volumeForReps() {
        let sets = [WorkoutSet(reps: 10, weight: 50), WorkoutSet(reps: 8, weight: 50)]
        #expect(ProgressCalculator.sessionValue(sets, metric: .volume) == 900)
    }

    @Test func volumeForLoadedHoldUsesSeconds() {
        #expect(ProgressCalculator.sessionValue([WorkoutSet(weight: 20, durationSeconds: 30)], metric: .volume) == 600)
    }

    @Test func volumeForBodyweightHoldIsTotalSeconds() {
        #expect(ProgressCalculator.sessionValue([WorkoutSet(durationSeconds: 25)], metric: .volume) == 25)
    }

    @Test func totalRepsSumsAndTreatsNilAsZero() {
        let sets = [WorkoutSet(reps: 12), WorkoutSet(reps: 10), WorkoutSet(reps: nil)]
        #expect(ProgressCalculator.sessionValue(sets, metric: .totalReps) == 22)
    }

    @Test func sessionValueOnEmptySetsIsZero() {
        for metric in ProgressMetric.allCases {
            #expect(ProgressCalculator.sessionValue([], metric: metric) == 0)
        }
    }

    // MARK: - Adherence

    @Test func adherenceThresholds() {
        #expect(ProgressCalculator.adherence(of: [WorkoutSet(rpe: 8)], target: 8) == .onTarget)
        #expect(ProgressCalculator.adherence(of: [WorkoutSet(rpe: 8.4)], target: 8) == .onTarget)
        #expect(ProgressCalculator.adherence(of: [WorkoutSet(rpe: 9)], target: 8) == .near)
        #expect(ProgressCalculator.adherence(of: [WorkoutSet(rpe: 9.5)], target: 8) == .off)
        #expect(ProgressCalculator.adherence(of: [WorkoutSet(rpe: 8)], target: nil) == .unknown)
        #expect(ProgressCalculator.adherence(of: [WorkoutSet()], target: 8) == .unknown)
    }

    @Test func adherenceAveragesAcrossSets() {
        // avg(7, 9) = 8 → on target
        #expect(ProgressCalculator.adherence(of: [WorkoutSet(rpe: 7), WorkoutSet(rpe: 9)], target: 8) == .onTarget)
        // avg(6, 8) = 7 → delta 1 → near
        #expect(ProgressCalculator.adherence(of: [WorkoutSet(rpe: 6), WorkoutSet(rpe: 8)], target: 8) == .near)
    }

    @Test func adherenceIgnoresUnloggedRPE() {
        // The nil-RPE set is dropped; only the 8 counts → on target.
        #expect(ProgressCalculator.adherence(of: [WorkoutSet(rpe: 8), WorkoutSet()], target: 8) == .onTarget)
    }

    // MARK: - points()

    @Test func pointsRespectDateCutoffAndSideFilter() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = Date()
        let recent = insertSession(context, daysAgo: 10, now: now)
        _ = insertSession(context, daysAgo: 100, now: now)
        let all = (try context.fetch(FetchDescriptor<Exercise>()))

        #expect(ProgressCalculator.points(for: all, metric: .topWeight, range: .month, now: now).count == 1)
        #expect(ProgressCalculator.points(for: all, metric: .topWeight, range: .year, now: now).count == 2)

        let left = ProgressCalculator.points(for: [recent], metric: .topWeight, range: .year, side: .left, now: now).first?.value
        let right = ProgressCalculator.points(for: [recent], metric: .topWeight, range: .year, side: .right, now: now).first?.value
        #expect(left == 40)
        #expect(right == 45)
    }

    @Test func pointsCutoffBoundaryIsInclusive() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = Date()
        let onBoundary = insertSession(context, daysAgo: 30, now: now)   // exactly the cutoff
        let justOutside = insertSession(context, daysAgo: 31, now: now)

        #expect(ProgressCalculator.points(for: [onBoundary], metric: .topWeight, range: .month, now: now).count == 1)
        #expect(ProgressCalculator.points(for: [justOutside], metric: .topWeight, range: .month, now: now).count == 0)
    }

    @Test func pointsExcludeZeroWorkPerMetric() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = Date()
        // Bodyweight session: reps only, no load.
        let bodyweight = insertSession(context, daysAgo: 5, now: now, leftWeight: nil, rightWeight: nil)

        // No load → excluded from a weight metric, but present for reps.
        #expect(ProgressCalculator.points(for: [bodyweight], metric: .topWeight, range: .year, now: now).isEmpty)
        #expect(ProgressCalculator.points(for: [bodyweight], metric: .totalReps, range: .year, now: now).count == 1)
    }

    @Test func pointsAreSortedAscendingByDate() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = Date()
        _ = insertSession(context, daysAgo: 5, now: now)
        _ = insertSession(context, daysAgo: 50, now: now)
        _ = insertSession(context, daysAgo: 20, now: now)
        let all = try context.fetch(FetchDescriptor<Exercise>())

        let dates = ProgressCalculator.points(for: all, metric: .topWeight, range: .year, now: now).map(\.date)
        #expect(dates == dates.sorted())
    }

    @Test func bestReturnsAllTimeMaxPerSide() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = Date()
        _ = insertSession(context, daysAgo: 40, now: now, leftWeight: 40, rightWeight: 45)
        _ = insertSession(context, daysAgo: 5, now: now, leftWeight: 50, rightWeight: 48)
        let all = try context.fetch(FetchDescriptor<Exercise>())

        #expect(ProgressCalculator.best(for: all, metric: .topWeight, side: .left) == 50)
        #expect(ProgressCalculator.best(for: all, metric: .topWeight, side: .right) == 48)
        #expect(ProgressCalculator.best(for: all, metric: .topWeight, side: nil) == 50)
    }

    // MARK: - Helpers

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Workout.self, Exercise.self, WorkoutSet.self,
            TrainingPlan.self, TemplateExercise.self, ExerciseDefinition.self,
            configurations: config
        )
    }

    @discardableResult
    private func insertSession(_ context: ModelContext, daysAgo: Int, now: Date, leftWeight: Double? = 40, rightWeight: Double? = 45) -> Exercise {
        let calendar = Calendar.current
        let workout = Workout(name: "W", date: calendar.date(byAdding: .day, value: -daysAgo, to: now)!)
        context.insert(workout)
        let exercise = Exercise(name: "Wrist flexion")
        context.insert(exercise)
        exercise.workout = workout
        let left = WorkoutSet(reps: 10, weight: leftWeight, side: "L", order: 0)
        let right = WorkoutSet(reps: 10, weight: rightWeight, side: "R", order: 1)
        context.insert(left); context.insert(right)
        left.exercise = exercise
        right.exercise = exercise
        return exercise
    }
}

struct PrescriptionParsingTests {

    @Test func targetRPEMidpointFromRange() {
        #expect(TemplateExercise(targetRPE: "5–6").targetRPEValue == 5.5)   // en dash
        #expect(TemplateExercise(targetRPE: "9-10").targetRPEValue == 9.5)  // hyphen
        #expect(TemplateExercise(targetRPE: "8").targetRPEValue == 8)
        #expect(TemplateExercise(targetRPE: "").targetRPEValue == nil)
    }

    @Test func restFormatting() {
        #expect(TemplateExercise.formatRest(45) == "45s")
        #expect(TemplateExercise.formatRest(90) == "1m 30s")
        #expect(TemplateExercise.formatRest(120) == "2 min")
        #expect(TemplateExercise.formatRest(150) == "2m 30s")
    }
}

@MainActor
struct ConsistencyTests {

    @Test func averageRecoveryComputesMeanGap() {
        let now = Date()
        let calendar = Calendar.current
        let viewModel = ProgressDashboardViewModel()
        viewModel.workouts = [0, 2, 5].map {
            Workout(name: "W", date: calendar.date(byAdding: .day, value: -$0, to: now)!)
        }
        // gaps between (-5,-2,0) sorted = 3 and 2 days → mean 2.5
        let average = viewModel.averageRecoveryDays(in: .month, now: now)
        #expect(average != nil)
        #expect(abs((average ?? 0) - 2.5) < 0.001)
    }

    @Test func averageRecoveryNeedsTwoSessions() {
        let now = Date()
        let viewModel = ProgressDashboardViewModel()
        viewModel.workouts = [Workout(name: "W", date: now)]
        #expect(viewModel.averageRecoveryDays(in: .month, now: now) == nil)
    }

    @Test func barsCoverWindowAndCountSessions() {
        let now = Date()
        let calendar = Calendar.current
        let viewModel = ProgressDashboardViewModel()
        viewModel.workouts = [
            Workout(name: "W", date: now),
            Workout(name: "W", date: calendar.date(byAdding: .day, value: -1, to: now)!),
        ]
        let bars = viewModel.bars(for: .twoWeeks, now: now)
        #expect(bars.count == 14)                                   // one bucket per day
        #expect(bars.reduce(0) { $0 + $1.count } == 2)              // both sessions land in-window
    }
}

@MainActor
struct SeedReconcileTests {

    @Test func reconcileFixesSeededFlagsOnly() throws {
        let container = try ModelContainer(
            for: Workout.self, Exercise.self, WorkoutSet.self,
            TrainingPlan.self, TemplateExercise.self, ExerciseDefinition.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext

        // A seeded entry with a stale flag (bilateral) that should be corrected.
        let stale = ExerciseDefinition(name: "Hammer curls")
        stale.isSeeded = true
        stale.tracksSides = false
        context.insert(stale)

        // A user's own definition that happens to share the name — must NOT be touched.
        let custom = ExerciseDefinition(name: "Hammer curls")
        custom.isSeeded = false
        custom.tracksSides = false
        context.insert(custom)

        // A seeded entry not in the canonical table — left alone.
        let unknown = ExerciseDefinition(name: "Zercher hold")
        unknown.isSeeded = true
        context.insert(unknown)

        SeedData.reconcileSeededDefinitions(context)

        #expect(stale.tracksSides == true)        // corrected
        #expect(custom.tracksSides == false)      // user definition untouched
        #expect(unknown.tracksSides == false)     // unknown name untouched
    }
}

@MainActor
struct BackupServiceTests {

    @Test func exportThenRestoreRebuildsTheGraph() throws {
        func container() throws -> ModelContainer {
            try ModelContainer(
                for: Workout.self, Exercise.self, WorkoutSet.self,
                TrainingPlan.self, TemplateExercise.self, ExerciseDefinition.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        }

        // Build a small graph in the source store.
        let source = try container()
        let sourceContext = source.mainContext
        let definition = ExerciseDefinition(name: "Wrist flexion")
        definition.tracksSides = true
        definition.equipmentRaw = Equipment.band.rawValue
        sourceContext.insert(definition)
        let workout = Workout(name: "Day 1", date: Date())
        sourceContext.insert(workout)
        let exercise = Exercise(name: "Wrist flexion", order: 0)
        exercise.tracksSides = true
        sourceContext.insert(exercise)
        exercise.workout = workout
        exercise.definition = definition
        let set = WorkoutSet(reps: 12, weight: 40, rpe: 6, side: SetSide.left.rawValue, order: 0)
        sourceContext.insert(set)
        set.exercise = exercise

        let data = try BackupService.export(sourceContext)

        // Restore into a separate, fresh store.
        let destination = try container()
        try BackupService.restore(from: data, into: destination.mainContext)
        let context = destination.mainContext

        #expect(try context.fetch(FetchDescriptor<ExerciseDefinition>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<Workout>()).count == 1)

        let restoredSets = try context.fetch(FetchDescriptor<WorkoutSet>())
        #expect(restoredSets.count == 1)
        #expect(restoredSets.first?.weight == 40)
        #expect(restoredSets.first?.side == "L")

        // Cross-reference (exercise → definition) rebuilt by name.
        let restoredWorkout = try context.fetch(FetchDescriptor<Workout>()).first
        #expect(restoredWorkout?.exercises?.first?.definition?.name == "Wrist flexion")
        #expect(try context.fetch(FetchDescriptor<ExerciseDefinition>()).first?.equipment == .band)
    }
}

@MainActor
struct WorkoutCreationTests {

    @Test func createWorkoutExpandsBothArmsAndPrefillsRPE() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Workout.self, Exercise.self, WorkoutSet.self,
            TrainingPlan.self, TemplateExercise.self, ExerciseDefinition.self,
            configurations: config
        )
        let context = container.mainContext

        let sidedDef = ExerciseDefinition(name: "Wrist flexion")
        sidedDef.tracksSides = true
        let plainDef = ExerciseDefinition(name: "Hammer curls")
        context.insert(sidedDef); context.insert(plainDef)

        let plan = TrainingPlan(name: "Test plan")
        context.insert(plan)
        let t1 = TemplateExercise(name: "Wrist flexion", order: 0, targetSets: 3, targetReps: "15–20", targetRPE: "6")
        let t2 = TemplateExercise(name: "Hammer curls", order: 1, targetSets: 4, targetReps: "12–15", targetRPE: "6")
        context.insert(t1); context.insert(t2)
        t1.definition = sidedDef; t1.plan = plan
        t2.definition = plainDef; t2.plan = plan

        let viewModel = WorkoutListViewModel()
        let workout = viewModel.createWorkout(from: plan, in: context)
        let exercises = (workout.exercises ?? []).sortedByOrder()

        #expect(exercises.count == 2)

        let sided = exercises[0]
        #expect(sided.tracksSides)
        #expect((sided.sets ?? []).count == 6)                                  // 3 left + 3 right
        #expect((sided.sets ?? []).filter { $0.side == "L" }.count == 3)
        #expect((sided.sets ?? []).filter { $0.side == "R" }.count == 3)
        #expect(sided.targetRPE == 6)
        #expect((sided.sets ?? []).allSatisfy { $0.rpe == 6 })                  // RPE pre-filled

        let plain = exercises[1]
        #expect(!plain.tracksSides)
        #expect((plain.sets ?? []).count == 4)
    }
}

@MainActor
struct NumericBridgeTests {

    @Test func asDoubleRoundTripsAndTruncates() {
        var stored: Int? = nil
        let bridged = Binding<Int?>(get: { stored }, set: { stored = $0 }).asDouble

        bridged.wrappedValue = 12.0
        #expect(stored == 12)
        #expect(bridged.wrappedValue == 12.0)

        // Reps are whole numbers — decimals truncate toward zero rather than round.
        bridged.wrappedValue = 8.7
        #expect(stored == 8)

        bridged.wrappedValue = nil      // blank clears the model (no data)
        #expect(stored == nil)
        #expect(bridged.wrappedValue == nil)
    }
}

struct EquipmentTests {

    /// The stepper and the suggestion chips both read `loadStep`, so this is the
    /// single source of truth that keeps bands at ±1 and plates at ±2.5.
    @Test func loadStepMatchesEquipment() {
        #expect(Equipment.freeWeight.loadStep == 2.5)
        #expect(Equipment.cable.loadStep == 2.5)
        #expect(Equipment.band.loadStep == 1)
        #expect(Equipment.bodyweight.loadStep == 0)
        #expect(Equipment.bodyweight.loadUnit == nil)
    }

    @MainActor
    @Test func exerciseLoadStepPrefersDefinitionOverride() {
        let exercise = Exercise(name: "Wrist flexion")
        exercise.equipmentRaw = Equipment.freeWeight.rawValue
        #expect(exercise.loadStep == 2.5)                 // falls back to equipment default

        let definition = ExerciseDefinition(name: "Wrist flexion")
        definition.stepKg = 1.25                          // microplates
        exercise.definition = definition
        #expect(exercise.loadStep == 1.25)                // custom step wins
    }
}

@MainActor
struct GuidedLoggerTests {

    // Returns the container (not just its context) so the caller retains it — a
    // ModelContext doesn't keep its container alive, so returning only the context
    // would leave it dangling and crash on use.
    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Workout.self, Exercise.self, WorkoutSet.self,
            TrainingPlan.self, TemplateExercise.self, ExerciseDefinition.self,
            configurations: config
        )
    }

    private func addSets(_ count: Int, side: String, startOrder: Int, to exercise: Exercise, in context: ModelContext) {
        for i in 0..<count {
            let set = WorkoutSet(side: side, order: startOrder + i)
            context.insert(set)
            set.exercise = exercise
        }
    }

    @Test func loadedRepsExerciseEmitsWeightRepsEffort() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let exercise = Exercise(name: "Curl", order: 0)
        exercise.equipmentRaw = Equipment.freeWeight.rawValue
        context.insert(exercise)
        addSets(2, side: "", startOrder: 0, to: exercise, in: context)

        let steps = GuidedLogger.steps(for: exercise)
        #expect(steps.count == 6)                                   // 2 sets × (weight, reps, effort)
        #expect(Array(steps.prefix(3).map(\.field)) == [.weight, .reps, .effort])
        #expect(steps.allSatisfy { $0.setCount == 2 })
        #expect(steps[0].setNumber == 1 && steps[3].setNumber == 2)
    }

    @Test func bodyweightExerciseSkipsWeight() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let exercise = Exercise(name: "Pushup", order: 0)
        exercise.equipmentRaw = Equipment.bodyweight.rawValue
        context.insert(exercise)
        addSets(1, side: "", startOrder: 0, to: exercise, in: context)

        #expect(GuidedLogger.steps(for: exercise).map(\.field) == [.reps, .effort])
    }

    @Test func timedLoadedExerciseUsesDuration() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let exercise = Exercise(name: "Hold", order: 0)
        exercise.equipmentRaw = Equipment.band.rawValue          // band is loaded
        exercise.isTimed = true
        context.insert(exercise)
        addSets(1, side: "", startOrder: 0, to: exercise, in: context)

        #expect(GuidedLogger.steps(for: exercise).map(\.field) == [.weight, .duration, .effort])
    }

    @Test func sidedExerciseWalksLeadArmFirstWithPerSideNumbering() throws {
        UserDefaults.standard.set(SetSide.right.rawValue, forKey: AppSettings.leadSideKey)
        let container = try makeContainer()
        let context = container.mainContext
        let exercise = Exercise(name: "Wrist flexion", order: 0)
        exercise.equipmentRaw = Equipment.freeWeight.rawValue
        exercise.tracksSides = true
        context.insert(exercise)
        addSets(2, side: "R", startOrder: 0, to: exercise, in: context)
        addSets(2, side: "L", startOrder: 2, to: exercise, in: context)

        let steps = GuidedLogger.steps(for: exercise)
        #expect(steps.count == 12)                                 // 4 sets × 3 fields
        #expect(steps.first?.set.side == "R")                      // lead arm first
        #expect(steps.last?.set.side == "L")
        let firstLeft = steps.first { $0.set.side == "L" }
        #expect(firstLeft?.setNumber == 1)                         // numbering resets per side
        #expect(firstLeft?.setCount == 2)
    }
}

struct BigStepperTests {

    @Test func adjustStepsAndClampsAtZero() {
        #expect(BigStepper.adjust(nil, by: -2.5) == 0)             // nil treated as 0
        #expect(BigStepper.adjust(nil, by: 2.5) == 2.5)
        #expect(BigStepper.adjust(2.5, by: 2.5) == 5)
        #expect(BigStepper.adjust(1, by: -5) == 0)                 // never goes negative
    }
}

struct EffortScaleTests {

    @Test func displayAndCanonicalConvertAndRoundTrip() {
        #expect(EffortScale.rpe.display(8) == 8)                   // RPE shows canonical as-is
        #expect(EffortScale.rpe.canonical(8) == 8)
        #expect(EffortScale.rir.display(8) == 2)                   // RIR = 10 − RPE
        #expect(EffortScale.rir.canonical(2) == 8)
        #expect(EffortScale.rir.canonical(EffortScale.rir.display(7)) == 7)
    }
}
