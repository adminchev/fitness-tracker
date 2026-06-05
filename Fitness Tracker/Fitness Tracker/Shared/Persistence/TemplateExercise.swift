import Foundation
import SwiftData

/// A prescribed exercise inside a `TrainingPlan` — the *plan* of what to do
/// (sets / reps / RPE / rest / coaching note), as opposed to the logged `Exercise`.
@Model final class TemplateExercise {
    var name: String = ""
    var order: Int = 0
    var targetSets: Int = 0
    /// Free-text so it can hold "15–20", "20–30 sec hold", "8 explosive reps", etc.
    var targetReps: String = ""
    var targetRPE: String = ""
    var restSeconds: Int = 0
    var notes: String = ""
    /// Created by the initial seed; protected from deletion in the UI.
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

    /// One-line guidance string, e.g. "3 × 15–20  ·  RPE 6  ·  rest 90s".
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

    /// Numeric prescribed RPE; ranges like "5–6" resolve to their midpoint (5.5).
    /// Used to auto-fill logged sets and to score adherence.
    var targetRPEValue: Double? {
        let cleaned = targetRPE.replacingOccurrences(of: "–", with: "-")   // en dash → hyphen
        let numbers = cleaned.split(separator: "-").compactMap {
            Double($0.trimmingCharacters(in: .whitespaces))
        }
        guard !numbers.isEmpty else { return nil }
        return numbers.reduce(0, +) / Double(numbers.count)
    }

    static func formatRest(_ seconds: Int) -> String {
        if seconds < 60 { return "\(seconds)s" }
        if seconds % 60 == 0 { return "\(seconds / 60) min" }
        let minutes = seconds / 60, remainder = seconds % 60
        return "\(minutes)m \(remainder)s"
    }
}
