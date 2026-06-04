internal import SwiftUI
import SwiftData

/// One set's input row: load (kg/band, hidden for bodyweight), reps *or* a hold
/// timer, and RPE. All fields are blank-aware via `NumericField`.
struct SetRowView: View {
    @Bindable var set: WorkoutSet
    let setNumber: Int
    var isTimed: Bool = false
    var equipment: Equipment = .freeWeight

    var body: some View {
        HStack(spacing: 12) {
            Text("\(setNumber)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .leading)

            if let unit = equipment.loadUnit {
                cell(unit) {
                    NumericField(placeholder: "—", value: $set.weight)
                }
            }
            if isTimed {
                cell("sec") {
                    TimedSetField(seconds: $set.durationSeconds)
                }
            } else {
                cell("reps") {
                    NumericField(placeholder: "—", value: intBinding($set.reps), isInteger: true)
                }
            }
            cell("RPE") {
                NumericField(placeholder: "—", value: $set.rpe)
            }
        }
        .padding(.vertical, 4)
    }

    private func intBinding(_ source: Binding<Int?>) -> Binding<Double?> {
        Binding(
            get: { source.wrappedValue.map(Double.init) },
            set: { source.wrappedValue = $0.map { Int($0) } }
        )
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
