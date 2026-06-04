internal import SwiftUI

/// A hold field: tap play to start a live count-up, tap stop to save the elapsed
/// seconds. When idle it's an ordinary editable numeric field, so manual entry
/// still works.
struct TimedSetField: View {
    @Binding var seconds: Int?
    @State private var startDate: Date?

    var body: some View {
        HStack(spacing: 6) {
            Group {
                if let startDate {
                    TimelineView(.periodic(from: .now, by: 0.5)) { context in
                        Text("\(max(Int(context.date.timeIntervalSince(startDate)), 0))")
                            .monospacedDigit()
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity)
                    }
                } else {
                    NumericField(placeholder: "—", value: secondsAsDouble, isInteger: true)
                }
            }

            Button {
                toggle()
            } label: {
                Image(systemName: startDate == nil ? "play.circle.fill" : "stop.circle.fill")
                    .foregroundStyle(startDate == nil ? Color.accentColor : .red)
            }
            .buttonStyle(.borderless)
        }
    }

    private var secondsAsDouble: Binding<Double?> {
        Binding(
            get: { seconds.map(Double.init) },
            set: { seconds = $0.map { Int($0) } }
        )
    }

    private func toggle() {
        if let startDate {
            seconds = max(Int(Date().timeIntervalSince(startDate)), 0)
            self.startDate = nil
        } else {
            startDate = Date()
        }
    }
}
