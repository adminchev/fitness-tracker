internal import SwiftUI

/// The accessible logging mode's single control: one value, two huge `−`/`+` targets.
/// Tap nudges by `step`; press-and-hold repeats, accelerating, so a big jump (0 → 40 kg)
/// doesn't take forty taps. The centre is a tap-to-type `NumericField` fallback for an
/// exact figure. Values clamp at 0 (and at `upperBound`, if given).
///
/// Accessibility: the −/+ are exposed as buttons with increment/decrement labels and an
/// activation action (one step per VoiceOver/Switch-Control activation), the value reads
/// its number or "Not set", sizes scale with Dynamic Type, and the press animation
/// respects Reduce Motion.
struct BigStepper: View {
    @Binding var value: Double?
    let step: Double
    /// Field name used to build the accessibility strings (e.g. "Weight").
    var label: String = "Value"
    var unit: String? = nil
    var isInteger: Bool = false
    var upperBound: Double? = nil
    var placeholder: String = "—"
    /// Fired once at the start of each press, before the value moves — the guided
    /// view uses it to snapshot the value for Undo (one entry per press, not per tick).
    var onChange: (() -> Void)? = nil

    @ScaledMetric(relativeTo: .largeTitle) private var valueSize: CGFloat = 52

    /// Pure increment, clamped at zero — shared by tap and hold, and unit-tested.
    static func adjust(_ value: Double?, by delta: Double) -> Double {
        max((value ?? 0) + delta, 0)
    }

    var body: some View {
        HStack(spacing: 16) {
            StepButton(systemName: "minus",
                       accessibilityLabel: "Decrease \(label)",
                       onBegin: { snapshotThenStep(-step) },
                       onRepeat: { step(by: -step) })
            VStack(spacing: 6) {
                NumericField(placeholder: placeholder, value: $value, isInteger: isInteger)
                    .font(.system(size: min(valueSize, 80), weight: .semibold).monospacedDigit())
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel(label)
                    .accessibilityValue(accessibilityValue)
                if let unit {
                    Text(unit)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }
            StepButton(systemName: "plus",
                       accessibilityLabel: "Increase \(label)",
                       onBegin: { snapshotThenStep(step) },
                       onRepeat: { step(by: step) })
        }
    }

    private var accessibilityValue: String {
        guard let value else { return "Not set" }
        let number = isInteger ? String(Int(value)) : value.formatted(.number.precision(.fractionLength(0...1)))
        return unit.map { "\(number) \($0)" } ?? number
    }

    private func snapshotThenStep(_ delta: Double) {
        onChange?()
        step(by: delta)
    }

    private func step(by delta: Double) {
        let stepped = Self.adjust(value, by: delta)
        value = upperBound.map { Swift.min(stepped, $0) } ?? stepped
    }
}

/// One oversized stepper button. A tap fires `onBegin` once; holding fires `onBegin`
/// immediately then `onRepeat` on an accelerating timer until release. Exposed to
/// assistive tech as a button that performs a single step per activation.
private struct StepButton: View {
    let systemName: String
    let accessibilityLabel: String
    let onBegin: () -> Void
    let onRepeat: () -> Void

    @ScaledMetric(relativeTo: .largeTitle) private var size: CGFloat = 84
    @ScaledMetric(relativeTo: .largeTitle) private var glyph: CGFloat = 30
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var repeatTask: Task<Void, Never>?
    @GestureState private var pressed = false

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 18) }

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: min(glyph, 44), weight: .bold))
            .foregroundStyle(.tint)
            .frame(width: min(size, 110), height: min(size, 110))
            .background(Color.accentColor.opacity(pressed ? 0.28 : 0.14), in: shape)
            .overlay(shape.strokeBorder(Color.accentColor.opacity(0.35), lineWidth: 1.5))
            .scaleEffect(reduceMotion ? 1 : (pressed ? 0.94 : 1))
            .contentShape(.rect)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.1), value: pressed)
            // A zero-distance drag gives us press-down and release without a Button's
            // tap-only semantics, so the same control handles tap and hold-to-repeat.
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($pressed) { _, state, _ in state = true }
                    .onChanged { _ in begin() }
                    .onEnded { _ in end() }
            )
            .onDisappear { end() }
            // Make it a real control for VoiceOver / Switch Control: one step per activation.
            .accessibilityElement()
            .accessibilityLabel(accessibilityLabel)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { onBegin() }
    }

    private func begin() {
        guard repeatTask == nil else { return }   // onChanged repeats; act once per press
        onBegin()
        repeatTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))   // hold threshold before repeating
            var interval = 0.18
            while !Task.isCancelled {
                onRepeat()
                try? await Task.sleep(for: .seconds(interval))
                interval = max(interval * 0.82, 0.04)         // accelerate, floor at 25/sec
            }
        }
    }

    private func end() {
        repeatTask?.cancel()
        repeatTask = nil
    }
}
