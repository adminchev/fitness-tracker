internal import SwiftUI

/// A numeric text field backed by an optional value. Shows blank (with a faint
/// placeholder) when the value is nil, so empty means "no data" — and you never
/// get a stuck leading zero. Decimal entry mid-typing is preserved; the field
/// reformats from the model only when it loses focus.
///
/// When focused it shows a keyboard accessory bar: tappable `suggestions` (sourced
/// from history by the caller) plus a Done button to dismiss the number pad.
struct NumericField: View {
    let placeholder: String
    @Binding var value: Double?
    var isInteger: Bool = false
    var suggestions: [Double] = []

    @State private var text: String = ""
    /// True only while we're writing our own typed value back to the model, so the
    /// resulting `value` change isn't mistaken for an external edit (see below).
    @State private var committing = false
    @FocusState private var focused: Bool

    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(isInteger ? .numberPad : .decimalPad)
            .focused($focused)
            .onChange(of: text) { _, newValue in commit(newValue) }
            .onChange(of: focused) { _, isFocused in if !isFocused { syncFromValue() } }
            // Resync the text from an *external* value change (e.g. a stepper tap)
            // even while focused — but ignore the echo of our own typed commit, which
            // would otherwise reformat mid-entry and eat a trailing decimal point.
            .onChange(of: value) { _, _ in
                if committing { committing = false } else { syncFromValue() }
            }
            .onAppear { syncFromValue() }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    if focused {
                        if !suggestions.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(suggestions, id: \.self) { suggestion in
                                        Button(label(for: suggestion)) {
                                            value = suggestion
                                            syncFromValue()
                                        }
                                        .buttonStyle(.bordered)
                                        .font(.body)
                                    }
                                }
                            }
                        }
                        Spacer()
                        // Pin a normal font: the field's caller may set a huge font
                        // (the accessible stepper does), which would otherwise inflate
                        // this keyboard-accessory button.
                        Button("Done") { focused = false }
                            .font(.body)
                    }
                }
            }
    }

    private func label(for value: Double) -> String {
        isInteger ? String(Int(value)) : value.formatted(.number.precision(.fractionLength(0...1)))
    }

    private func syncFromValue() {
        guard let value else { text = ""; return }
        text = isInteger ? String(Int(value)) : value.formatted(.number.precision(.fractionLength(0...2)))
    }

    private func commit(_ string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespaces)
        let newValue: Double?
        if trimmed.isEmpty {
            newValue = nil
        } else if let parsed = Self.parse(trimmed) {
            newValue = parsed
        } else {
            return   // Unparseable in-progress input (e.g. "12,") — leave `text` as-is.
        }
        // Flag only on a real change, so the `value` onChange is guaranteed to fire
        // and clear it; a no-op assignment would otherwise leave it stuck true.
        guard newValue != value else { return }
        committing = true
        value = newValue
    }

    /// Locale-tolerant parse: the number pad inserts the *locale's* decimal separator
    /// (a comma in much of the world), which `Double.init` doesn't accept — so a comma
    /// entry like "8,5" would otherwise be silently rejected.
    static func parse(_ string: String, locale: Locale = .current) -> Double? {
        if let value = Double(string) { return value }
        var normalized = string
        if let grouping = locale.groupingSeparator {
            normalized = normalized.replacingOccurrences(of: grouping, with: "")
        }
        if let decimal = locale.decimalSeparator, decimal != "." {
            normalized = normalized.replacingOccurrences(of: decimal, with: ".")
        }
        return Double(normalized)
    }
}
