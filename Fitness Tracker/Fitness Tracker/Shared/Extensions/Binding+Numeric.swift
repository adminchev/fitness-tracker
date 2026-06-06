internal import SwiftUI

extension Binding where Value == Int? {
    /// Bridges an optional-`Int` model property to the `Double?`-based numeric
    /// controls (`NumericField`, the steppers) without each call site re-deriving
    /// the same get/set dance. Reps are stored as `Int` but edited as `Double`.
    var asDouble: Binding<Double?> {
        Binding<Double?>(
            get: { self.wrappedValue.map { Double($0) } },
            set: { newValue in self.wrappedValue = newValue.map { Int($0) } }
        )
    }
}
