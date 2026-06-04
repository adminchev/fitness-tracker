internal import SwiftUI

/// A numeric text field backed by an optional value. Shows blank (with a faint
/// placeholder) when the value is nil, so empty means "no data" — and you never
/// get a stuck leading zero. Decimal entry mid-typing is preserved; the field
/// reformats from the model only when it loses focus.
struct NumericField: View {
    let placeholder: String
    @Binding var value: Double?
    var isInteger: Bool = false

    @State private var text: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(isInteger ? .numberPad : .decimalPad)
            .focused($focused)
            .onChange(of: text) { _, newValue in commit(newValue) }
            .onChange(of: focused) { _, isFocused in if !isFocused { syncFromValue() } }
            .onChange(of: value) { _, _ in if !focused { syncFromValue() } }
            .onAppear { syncFromValue() }
    }

    private func syncFromValue() {
        guard let value else { text = ""; return }
        text = isInteger ? String(Int(value)) : value.formatted(.number.precision(.fractionLength(0...2)))
    }

    private func commit(_ string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            value = nil
        } else if let parsed = Double(trimmed) {
            value = parsed
        }
        // Unparseable in-progress input (e.g. "12.") is left as-is in `text`.
    }
}
