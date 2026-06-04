import Foundation
import SwiftData

@Model final class TemplateExercise {
    var name: String = ""
    var order: Int = 0
    var targetSets: Int = 0
    var targetReps: String = ""
    var targetRPE: String = ""
    var restSeconds: Int = 0
    var notes: String = ""
    /// True for exercises created by the initial seed; these are protected from deletion.
    var isSeeded: Bool = false
    var plan: TrainingPlan? = nil
    var definition: ExerciseDefinition? = nil

    init(name: String = "", order: Int = 0, targetSets: Int = 0, targetReps: String = "", targetRPE: String = "", restSeconds: Int = 0, notes: String = "") {
        self.name = name
        self.order = order
        self.targetSets = targetSets
        self.targetReps = targetReps
        self.targetRPE = targetRPE
        self.restSeconds = restSeconds
        self.notes = notes
    }

    var prescriptionSummary: String {
        var parts: [String] = []
        if targetSets > 0 && !targetReps.isEmpty {
            parts.append("\(targetSets) × \(targetReps)")
        } else if !targetReps.isEmpty {
            parts.append(targetReps)
        }
        if !targetRPE.isEmpty { parts.append("RPE \(targetRPE)") }
        if restSeconds > 0 { parts.append("rest \(Self.formatRest(restSeconds))") }
        return parts.joined(separator: "  ·  ")
    }

    /// Numeric prescribed RPE; ranges like "5–6" resolve to their midpoint.
    var targetRPEValue: Double? {
        let cleaned = targetRPE.replacingOccurrences(of: "–", with: "-")
        let numbers = cleaned.split(separator: "-").compactMap {
            Double($0.trimmingCharacters(in: .whitespaces))
        }
        guard !numbers.isEmpty else { return nil }
        return numbers.reduce(0, +) / Double(numbers.count)
    }

    static func formatRest(_ seconds: Int) -> String {
        if seconds < 60 { return "\(seconds)s" }
        if seconds % 60 == 0 { return "\(seconds / 60) min" }
        let m = seconds / 60, s = seconds % 60
        return "\(m)m \(s)s"
    }
}
