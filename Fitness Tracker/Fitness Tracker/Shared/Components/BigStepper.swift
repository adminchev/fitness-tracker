internal import SwiftUI

/// The accessible logging mode's single control: one value, two huge `−`/`+` targets.
/// Tap nudges by `step`; press-and-hold repeats, accelerating, so a big jump (0 → 40 kg)
/// doesn't take forty taps. The centre is a tap-to-type `NumericField` fallback for an
/// exact figure. Values clamp at 0 (and at `upperBound`, if given).
struct BigStepper: View {
    @Binding var value: Double?
    let step: Double
    var unit: String? = nil
    var isInteger: Bool = false
    var upperBound: Double? = nil
    var placeholder: String = "—"
    /// Fired once at the start of each press, before the value moves — the guided
    /// view uses it to snapshot the value for Undo (one entry per press, not per tick).
    var onChange: (() -> Void)? = nil

    /// Pure increment, clamped at zero — shared by tap and hold, and unit-tested.
    static func adjust(_ value: Double?, by delta: Double) -> Double {
        max((value ?? 0) + delta, 0)
    }

    var body: some View {
        HStack(spacing: 20) {
            StepButton(systemName: "minus",
                       onBegin: { snapshotThenStep(-step) },
                       onRepeat: { step(by: -step) })
            VStack(spacing: 6) {
                NumericField(placeholder: placeholder, value: $value, isInteger: isInteger)
                    .font(.system(size: 56, weight: .semibold).monospacedDigit())
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                if let unit {
                    Text(unit)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }
            StepButton(systemName: "plus",
                       onBegin: { snapshotThenStep(step) },
                       onRepeat: { step(by: step) })
        }
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
/// immediately then `onRepeat` on an accelerating timer until release.
private struct StepButton: View {
    let systemName: String
    let onBegin: () -> Void
    let onRepeat: () -> Void

    @State private var repeatTask: Task<Void, Never>?
    @GestureState private var pressed = false

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 32, weight: .bold))
            .frame(width: 84, height: 84)
            .background(pressed ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.quaternary),
                        in: RoundedRectangle(cornerRadius: 18))
            .scaleEffect(pressed ? 0.94 : 1)
            .contentShape(.rect)
            .animation(.easeOut(duration: 0.1), value: pressed)
            // A zero-distance drag gives us press-down and release without a Button's
            // tap-only semantics, so the same control handles tap and hold-to-repeat.
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($pressed) { _, state, _ in state = true }
                    .onChanged { _ in begin() }
                    .onEnded { _ in end() }
            )
            .onDisappear { end() }
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
