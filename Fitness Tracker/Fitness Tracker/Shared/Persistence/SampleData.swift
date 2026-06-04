#if DEBUG
import Foundation
import SwiftData

/// Generates a few weeks of realistic past sessions so the progress features
/// can be explored without logging by hand. Debug builds only.
@MainActor
enum SampleData {
    static func generate(_ context: ModelContext) {
        let plans = (try? context.fetch(FetchDescriptor<TrainingPlan>(sortBy: [SortDescriptor(\.order)]))) ?? []
        guard !plans.isEmpty else { return }

        let calendar = Calendar.current
        let sessionCount = 72

        for session in 0..<sessionCount {
            let plan = plans[session % plans.count]
            let daysAgo = (sessionCount - session) * 5      // ~ every 5 days over ~12 months
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: Date()) else { continue }

            let workout = Workout(name: plan.name, date: date)
            workout.trainingPlan = plan
            context.insert(workout)

            for (index, template) in (plan.templateExercises ?? []).sortedByOrder().enumerated() {
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

                let sides: [SetSide?] = exercise.tracksSides ? [.left, .right] : [nil]
                var order = 0
                for side in sides {
                    let sideBoost = side == .right ? 1.06 : 1.0   // right arm a touch stronger
                    // One RPE offset per side per session → varied adherence colors.
                    let rpeOffset: Double = [-1.5, -0.5, 0.0, 0.5, 1.5].randomElement() ?? 0
                    for _ in 0..<max(template.targetSets, 1) {
                        let set = makeSet(template: template, exercise: exercise, session: session,
                                          sideBoost: sideBoost, rpeOffset: rpeOffset, side: side?.rawValue ?? "", order: order)
                        order += 1
                        context.insert(set)
                        set.exercise = exercise
                    }
                }
            }
        }

        try? context.save()
    }

    private static func makeSet(template: TemplateExercise, exercise: Exercise, session: Int, sideBoost: Double, rpeOffset: Double, side: String, order: Int) -> WorkoutSet {
        let set = WorkoutSet(side: side, order: order)
        let progress = Double(session) * 0.5   // creeps up each session

        if let target = exercise.targetRPE {
            set.rpe = (target + rpeOffset).clamped(to: 5...10)
        }

        if exercise.isTimed {
            let base = firstInt(in: template.targetReps) ?? 25
            set.durationSeconds = Int((Double(base) + progress) * sideBoost) + Int.random(in: -2...2)
        } else {
            let base = firstInt(in: template.targetReps) ?? 10
            set.reps = max(base + Int.random(in: -1...1), 1)
        }

        if exercise.equipment != .bodyweight {
            let base = baseLoad(for: exercise.equipment)
            let value = ((base + progress) * sideBoost) + Double(Int.random(in: -1...1)) * 0.5
            set.weight = (value * 2).rounded() / 2   // nearest 0.5
        }

        return set
    }

    private static func baseLoad(for equipment: Equipment) -> Double {
        switch equipment {
        case .freeWeight: 10
        case .cable: 15
        case .band: 12
        case .bodyweight: 0
        }
    }

    private static func firstInt(in string: String) -> Int? {
        var digits = ""
        for character in string {
            if character.isNumber { digits.append(character) }
            else if !digits.isEmpty { break }
        }
        return Int(digits)
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
#endif
