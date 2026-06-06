internal import SwiftUI
import SwiftData

/// Finger-friendly logging layout: each set is a card with big −/+ steppers for load
/// and reps (the value stays tappable to type an exact number), an enlarged hold
/// timer, and a large effort pill. Chosen via Settings → Set controls.
struct BigButtonSetRow: View {
    @Bindable var set: WorkoutSet
    let setNumber: Int
    var isTimed: Bool = false
    var equipment: Equipment = .freeWeight
    var weightSuggestions: [Double] = []
    var repSuggestions: [Double] = []
    @AppStorage(AppSettings.effortScaleKey) private var effortRaw = EffortScale.rpe.rawValue

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Set \(setNumber)").font(.headline)
                Spacer()
                effortControl
            }

            if let unit = equipment.loadUnit {
                labeled(unit) {
                    StepperField(value: $set.weight, step: equipment.loadStep,
                                 placeholder: "—", suggestions: weightSuggestions)
                }
            }
            if isTimed {
                labeled("sec") {
                    TimedSetField(seconds: $set.durationSeconds, large: true)
                        .font(.title2.monospacedDigit())
                        .frame(maxWidth: .infinity)
                }
            } else {
                labeled("reps") {
                    StepperField(value: $set.reps.asDouble, step: 1,
                                 placeholder: "—", isInteger: true, suggestions: repSuggestions)
                }
            }
        }
        .padding(14)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 14))
    }

    private var effortControl: some View {
        VStack(spacing: 2) {
            EffortField(rpe: $set.rpe)
                .font(.title3)
                .frame(minWidth: 56)
                .padding(.vertical, 8)
                .padding(.horizontal, 14)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
            Text(effortRaw == EffortScale.rir.rawValue ? "RIR" : "RPE")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func labeled<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 42, alignment: .leading)
            content()
        }
    }
}

/// A large numeric control: oversized −/+ buttons flanking a value that's still
/// tappable to type an exact figure. The minus never takes the value below zero.
private struct StepperField: View {
    @Binding var value: Double?
    let step: Double
    let placeholder: String
    var isInteger: Bool = false
    var suggestions: [Double] = []

    var body: some View {
        HStack(spacing: 10) {
            stepButton("minus") { adjust(-step) }
            NumericField(placeholder: placeholder, value: $value, isInteger: isInteger, suggestions: suggestions)
                .font(.title2.monospacedDigit())
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            stepButton("plus") { adjust(step) }
        }
    }

    private func stepButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.title2.weight(.semibold))
                .frame(width: 52, height: 52)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private func adjust(_ delta: Double) {
        value = max((value ?? 0) + delta, 0)
    }
}
