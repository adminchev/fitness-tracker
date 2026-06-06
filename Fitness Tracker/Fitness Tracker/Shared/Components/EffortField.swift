internal import SwiftUI

/// Effort input, bound to the canonical RPE (0–10, where 10 = failure). Depending on
/// the Settings toggle it's shown and entered as either RPE or RIR (reps in reserve,
/// 0 = failure). RIR is simply displayed as `10 − RPE`; storage stays RPE, so plans,
/// adherence colours, and progress are unaffected by the choice.
struct EffortField: View {
    @Binding var rpe: Double?
    @AppStorage(AppSettings.effortScaleKey) private var scaleRaw = EffortScale.rpe.rawValue

    private var scale: EffortScale { EffortScale(rawValue: scaleRaw) ?? .rpe }
    private let options = Array(stride(from: 0.0, through: 10.0, by: 0.5))

    var body: some View {
        Menu {
            Button("Not set") { rpe = nil }
            ForEach(options, id: \.self) { shown in
                Button(text(shown)) { rpe = canonical(from: shown) }
            }
        } label: {
            Text(displayValue.map(text) ?? "—")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }

    /// The value to show for the current scale (RIR = 10 − RPE).
    private var displayValue: Double? {
        rpe.map(scale.display)
    }

    /// Convert a shown value back to canonical RPE for storage.
    private func canonical(from shown: Double) -> Double {
        scale.canonical(shown)
    }

    private func text(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }
}
