internal import SwiftUI
import SwiftData

/// Dense logging layout (the default): load (kg/band, hidden for bodyweight), reps
/// *or* a hold timer, and effort — each a small tappable cell you type into. Fast on
/// a steady hand; pick "Big buttons" in Settings for larger targets.
struct CompactSetRow: View {
    @Bindable var set: WorkoutSet
    let setNumber: Int
    var isTimed: Bool = false
    var equipment: Equipment = .freeWeight
    var weightSuggestions: [Double] = []
    var repSuggestions: [Double] = []
    @AppStorage(AppSettings.effortScaleKey) private var effortRaw = EffortScale.rpe.rawValue

    var body: some View {
        HStack(spacing: 12) {
            Text("\(setNumber)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .leading)

            if let unit = equipment.loadUnit {
                cell(unit) {
                    NumericField(placeholder: "—", value: $set.weight, suggestions: weightSuggestions)
                }
            }
            if isTimed {
                cell("sec") {
                    TimedSetField(seconds: $set.durationSeconds)
                }
            } else {
                cell("reps") {
                    NumericField(placeholder: "—", value: $set.reps.asDouble, isInteger: true, suggestions: repSuggestions)
                }
            }
            cell(effortRaw == EffortScale.rir.rawValue ? "RIR" : "RPE") {
                EffortField(rpe: $set.rpe)
            }
        }
        .padding(.vertical, 4)
    }

    private func cell<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 2) {
            content()
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
