import Foundation
import SwiftData

/// Seeds the exercise catalog and the three arm-wrestling training phases
/// the first time the app runs against an empty store.
@MainActor
enum SeedData {
    static func seedIfNeeded(_ context: ModelContext) {
        let existing = (try? context.fetchCount(FetchDescriptor<ExerciseDefinition>())) ?? 0
        guard existing == 0 else { return }
        seed(context)
    }

    static func seed(_ context: ModelContext) {
        func define(_ name: String, equipment: Equipment = .freeWeight, timed: Bool = false, sides: Bool = false) -> ExerciseDefinition {
            let d = ExerciseDefinition(name: name)
            d.isSeeded = true
            d.isTimed = timed
            d.tracksSides = sides
            d.equipmentRaw = equipment.rawValue
            context.insert(d)
            return d
        }

        let wristFlexion = define("Wrist flexion", equipment: .freeWeight, sides: true)
        let pronation = define("Pronation", equipment: .band, sides: true)
        let hammerCurls = define("Hammer curls", equipment: .freeWeight)
        let extensorOpens = define("Extensor band opens", equipment: .band)
        let cuppingHolds = define("Cupping holds", equipment: .freeWeight, timed: true, sides: true)
        let sidePressure = define("Side pressure isometrics", equipment: .band, timed: true, sides: true)
        let backPressureRows = define("Back pressure rows", equipment: .band, sides: true)
        let pinHolds = define("Pin holds (match-angle)", equipment: .freeWeight, timed: true, sides: true)
        let matchSim = define("Full match simulation", equipment: .bodyweight, sides: true)
        let wristRoller = define("Wrist roller", equipment: .freeWeight)

        // (definition, sets, reps, rpe, restSeconds, notes)
        typealias Item = (ExerciseDefinition, Int, String, String, Int, String)

        func makePlan(_ name: String, order: Int, summary: String, _ items: [Item]) {
            let plan = TrainingPlan(name: name, order: order, summary: summary)
            plan.isSeeded = true
            context.insert(plan)
            for (index, item) in items.enumerated() {
                let (def, sets, reps, rpe, rest, notes) = item
                let te = TemplateExercise(name: def.name, order: index, targetSets: sets, targetReps: reps, targetRPE: rpe, restSeconds: rest, notes: notes)
                te.isSeeded = true
                context.insert(te)
                te.definition = def
                te.plan = plan
            }
        }

        makePlan("Phase 1 — Foundation", order: 0,
                 summary: "Weeks 1–4. Tendon conditioning and movement patterns. Train 2×/week, 48h apart. The slow eccentric is the mechanism — a fast rep trains muscle, a controlled negative remodels tendon. Don't rush the tempo.",
                 [
                    (wristFlexion, 3, "15–20", "6", 90, "Supinated grip; 3-second negative; full ROM; light dumbbell or loading pin"),
                    (pronation, 3, "15–20", "5–6", 90, "Band anchored at table height; smooth rotation, no jerking"),
                    (hammerCurls, 3, "12–15", "6", 90, "Neutral grip; builds the brachioradialis base; 2-second negative"),
                    (extensorOpens, 3, "20–25", "5", 60, "Rubber band around fingers; open fully, close slowly; critical for injury prevention"),
                    (cuppingHolds, 3, "20–30 sec hold", "6", 90, "Wrist trainer or handle; deep cup position; focus on finger wrap, not squeeze"),
                 ])

        makePlan("Phase 2 — Strength Building", order: 1,
                 summary: "Weeks 5–8. Load the patterns. 3×/week (2 strength + 1 table). Side-pressure isometrics are the most specific and most-skipped lift — set them up anyway. Back pressure is the entry point to the hook.",
                 [
                    (wristFlexion, 4, "8–12", "8", 120, "Heavy flexion; add 5–10% over Phase 1; 2-second negative; use chalk"),
                    (pronation, 4, "10–12", "7–8", 120, "Loaded; switch to a pronation strap if available; feel the full rotation"),
                    (sidePressure, 3, "15–20 sec hold", "8", 90, "Band at table height; press outward in the back-pressure direction; hold hard"),
                    (backPressureRows, 3, "12–15", "7", 90, "Row band from a low anchor in the back-pressure plane; builds the hook setup"),
                    (cuppingHolds, 4, "20–30 sec hold", "8", 120, "Loaded; loading pin or AW handle; squeeze deep, not at the fingertips"),
                    (extensorOpens, 2, "25–30", "5", 60, "Maintenance; counterbalances the increased flexion loading"),
                 ])

        makePlan("Phase 3 — Table-Specific Power", order: 2,
                 summary: "Weeks 9–12. Peak intensity, match-specific patterns. 3×/week. Week 12 is a deload: cut all sets by 40%, stay below RPE 9, arrive fresh.",
                 [
                    (wristFlexion, 5, "5–6", "9", 180, "Explosive; arm wrestling handle; accelerate through full ROM; full reset between reps; power, not endurance"),
                    (pronation, 4, "8 explosive reps", "8–9", 120, "Light-to-moderate band; maximum rotational velocity; mimics the pronation start"),
                    (pinHolds, 5, "10–15 sec hold", "9–10", 180, "Load the AW handle near-max; hold in your weakest match position; builds the sticking point"),
                    (matchSim, 4, "10–15 sec efforts", "9", 210, "Partner; short max-effort exchanges from the go position; reset grip between rounds (3–5 rounds)"),
                    (cuppingHolds, 4, "15–20 sec hold", "9", 180, "Heaviest load yet; your strength peak; use chalk every set"),
                    (wristRoller, 2, "2 full rolls", "7", 120, "Forearm endurance flush; do this last; omit in the Week 12 deload"),
                 ])

        try? context.save()
    }
}
