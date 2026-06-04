Add a new reusable SwiftUI component named "$ARGUMENTS View" to the fitness tracker app.

Follow these steps exactly:

1. Create `Shared/Components/$ARGUMENTS View.swift` as a SwiftUI `View` struct that:
   - Is **data-agnostic** — accepts all data as parameters (no `@Environment`, no ViewModel, no SwiftData access)
   - Uses value types (String, Int, Double, etc.) or simple model structs as parameters, not `@Model` classes
   - Is previewed with inline hardcoded sample values (components don't need a ModelContainer)
   - Has a clear, single responsibility

   Example structure:
   ```swift
   import SwiftUI

   struct $ARGUMENTS View: View {
       let title: String
       let value: String
       // add your parameters here

       var body: some View {
           // your layout
       }
   }

   #Preview {
       $ARGUMENTS View(title: "Sample", value: "42")
   }
   ```

2. Do NOT inject `ModelContext`, `@EnvironmentObject`, or any ViewModel into this component.
3. If the component needs actions (button taps etc.), accept them as `() -> Void` closure parameters.

Components should be small, focused, and easily testable in isolation.
