Add a new feature screen to the fitness tracker app named "$ARGUMENTS".

Follow these steps exactly:

1. Create `Features/$ARGUMENTS/$ARGUMENTS View.swift` — a SwiftUI `View` struct that:
   - Has `@State private var viewModel = $ARGUMENTS ViewModel()` as its only state
   - Delegates all data fetching and actions to the ViewModel
   - Contains no business logic in `body`
   - Includes a `#Preview` block using an in-memory `ModelContainer` (see preview pattern in CLAUDE.md)

2. Create `Features/$ARGUMENTS/$ARGUMENTS ViewModel.swift` — an `@Observable final class` that:
   - Accepts `ModelContext` via `init(modelContext: ModelContext)`
   - Contains all data fetching, filtering, and mutation logic
   - Uses SwiftData queries (`try modelContext.fetch(...)`) — NOT `@Query`
   - Has no SwiftUI imports (import Foundation and SwiftData only)

3. Update `App/ContentView.swift` to add a `NavigationLink` or `TabView` entry for the new feature.

Use UpperCamelCase for the feature name in code. Follow all conventions in CLAUDE.md.
Do NOT use `@ObservableObject`, `@StateObject`, `@Published`, UIKit, or Combine.
