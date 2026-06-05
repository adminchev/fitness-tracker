internal import SwiftUI

/// A hold field that doubles as a stopwatch: type a value, or tap to start a live
/// count-up and tap again to save the elapsed seconds. While running, the field
/// shows the live time in red; idle, it's an ordinary editable number.
struct TimedSetField: View {
    @Binding var seconds: Int?
    @State private var startDate: Date?

    var body: some View {
        HStack(spacing: 8) {
            if let startDate {
                TimelineView(.periodic(from: .now, by: 0.5)) { context in
                    Text("\(elapsed(from: startDate, to: context.date))")
                        .monospacedDigit()
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                }
            } else {
                NumericField(placeholder: "—", value: secondsAsDouble, isInteger: true)
            }

            Button {
                toggle()
            } label: {
                Image(systemName: startDate == nil ? "timer" : "stop.fill")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(startDate == nil ? Color.accentColor : .red)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .contentShape(.rect)
        }
    }

    private var secondsAsDouble: Binding<Double?> {
        Binding(
            get: { seconds.map(Double.init) },
            set: { seconds = $0.map { Int($0) } }
        )
    }

    private func elapsed(from start: Date, to now: Date) -> Int {
        max(Int(now.timeIntervalSince(start)), 0)
    }

    private func toggle() {
        if let startDate {
            seconds = elapsed(from: startDate, to: Date())
            self.startDate = nil
        } else {
            startDate = Date()
        }
    }
}
