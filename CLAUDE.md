# Fitness Tracker — Claude Code Steering File

## Project Overview

An iOS fitness tracking app for personal use. Core features:
- **Workout logging** — record exercises, sets, reps, and weight per session
- **Progress tracking** — visualize strength gains and PRs over time

Platform: iPhone only. No web, no Android, no iPad optimization needed.

---

## Stack & Constraints

| Layer | Choice |
|---|---|
| UI | SwiftUI |
| Data | SwiftData |
| Sync | CloudKit (via SwiftData's built-in integration) |
| Min deployment | iOS 17.0 |
| Xcode | 16+ |
| Language | Swift 5.10+ |

**No third-party dependencies** without explicit user approval. Use Apple frameworks only.

---

## Architecture: MVVM with `@Observable`

This project uses the **modern Swift observation system** introduced in iOS 17. Do NOT use the old patterns.

### Correct pattern
```swift
// ViewModel
@Observable
final class WorkoutViewModel {
    var workouts: [Workout] = []
}

// View
struct WorkoutView: View {
    @State private var viewModel = WorkoutViewModel()
    var body: some View { ... }
}
```

### Forbidden patterns — never use these
```swift
// WRONG — pre-iOS 17, do not use
class OldViewModel: ObservableObject {
    @Published var workouts: [Workout] = []
}
struct OldView: View {
    @StateObject private var viewModel = OldViewModel()
    @ObservedObject var viewModel: OldViewModel
}
```

### Rules
- ViewModels are `@Observable final class` — one per feature screen
- Views are `struct` — no business logic, no direct SwiftData queries
- Pass the model context to ViewModels via init, not via `@Environment(\.modelContext)` in the ViewModel
- Views may read `@Environment(\.modelContext)` only to pass it into a ViewModel

---

## Project Structure

The Xcode project lives at `Fitness Tracker/Fitness Tracker/` within the repo root.

```
Fitness Tracker/Fitness Tracker/
  Features/
    Workout/
      WorkoutView.swift
      WorkoutViewModel.swift
      WorkoutDetailView.swift
      WorkoutDetailViewModel.swift
    Progress/
      ProgressView.swift
      ProgressViewModel.swift
  Shared/
    Components/        # Reusable SwiftUI views — data-agnostic, params only
    Extensions/        # Swift/SwiftUI extensions
    Persistence/       # All @Model classes + ModelContainer setup
      Workout.swift
      Exercise.swift
      WorkoutSet.swift
      PersistenceController.swift
  App/
    Fitness_TrackerApp.swift   # @main entry point
    ContentView.swift          # Top-level navigation (TabView)
```

New features go in `Features/[FeatureName]/`. Reusable UI goes in `Shared/Components/`. Never mix feature logic into Shared.

---

## SwiftData Schema

All `@Model` classes live in `Shared/Persistence/`. The canonical models:

```swift
@Model final class Workout {
    var date: Date = Date()
    var name: String = ""
    @Relationship(deleteRule: .cascade, inverse: \Exercise.workout) var exercises: [Exercise]? = []
}

@Model final class Exercise {
    var name: String = ""
    var order: Int = 0
    var workout: Workout? = nil   // inverse of Workout.exercises
    @Relationship(deleteRule: .cascade, inverse: \WorkoutSet.exercise) var sets: [WorkoutSet]? = []
}

@Model final class WorkoutSet {
    var reps: Int = 0
    var weight: Double = 0.0
    var order: Int = 0
    var exercise: Exercise? = nil   // inverse of Exercise.sets
}
```

When adding new models, follow this same structure.

---

## CloudKit Rules

SwiftData + CloudKit is enabled via `ModelConfiguration(cloudKitDatabase: .automatic)` in `PersistenceController`.

**SwiftData relationship rules (learned the hard way):**
- **Every relationship must have a declared inverse.** Use `@Relationship(deleteRule:, inverse:)` on the to-many side, and a plain optional to-one property on the other side. Without an inverse, SwiftData's change tracking is unreliable — to-many additions past the first won't propagate to the UI, and CloudKit sync silently fails.
- **Mutate relationships by setting the to-one (child) side**, then let SwiftData maintain the to-many: `child.parent = parent` (after `context.insert(child)`). Do NOT reassign the whole to-many array (`parent.children = ... + [child]`) — that fights the framework.
- **Screens that edit a single `@Model` observe it directly** via `@Bindable var model: SomeModel` (or a plain `var`), NOT through a ViewModel. ViewModels are for list screens that fetch with `FetchDescriptor`. Observation through a `let model` on an `@Observable` ViewModel does not track the model's own property changes.

**Mandatory CloudKit requirements — violations will cause silent sync failures:**
1. Every `@Model` property must be **optional or have a default value** — no bare non-optional stored properties
2. Every `@Relationship` must specify a `deleteRule`
3. No unique constraints (`@Attribute(.unique)`) — CloudKit doesn't support them
4. No `Codable` enum properties without a default — use `Int` or `String` raw values with defaults

---

## Naming Conventions

Follow [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/).

| Thing | Convention | Example |
|---|---|---|
| Types, protocols | UpperCamelCase | `WorkoutViewModel` |
| Functions, vars, params | lowerCamelCase | `fetchWorkouts()` |
| Views | Suffixed `View` | `WorkoutDetailView` |
| ViewModels | Suffixed `ViewModel` | `WorkoutDetailViewModel` |
| SwiftData models | No suffix | `Workout`, `Exercise` |
| Files | Match type name exactly | `WorkoutViewModel.swift` |

---

## What NOT to Do

- No UIKit (`UIViewController`, `UIView`, `AppDelegate` patterns)
- No Combine (`Publisher`, `sink`, `@Published`)
- No `@ObservableObject` / `@StateObject` / `@ObservedObject`
- No CoreData (use SwiftData only)
- No force unwrap (`!`) outside of tests
- No hardcoded data in previews — use `#Preview` with a temporary in-memory `ModelContainer`
- No singletons for state — use `@Observable` ViewModels injected via `@State`
- No logic in View `body` — extract to ViewModel methods

---

## Preview Pattern

Always use an in-memory container in previews, never hardcoded structs:

```swift
#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Workout.self, configurations: config)
    return WorkoutView()
        .modelContainer(container)
}
```

---

## Build & Test Commands

The Xcode scheme is **"Fitness Tracker"** (with a space). Always quote it.

```bash
# Build for simulator
xcodebuild -scheme "Fitness Tracker" -destination 'platform=iOS Simulator,name=iPhone 17' build

# Run tests
xcodebuild -scheme "Fitness Tracker" -destination 'platform=iOS Simulator,name=iPhone 17' test

# Clean build
xcodebuild -scheme "Fitness Tracker" clean
```

---

## Key Decisions Log

- **SwiftData over CoreData** — SwiftData is the modern API, less boilerplate, better Swift integration
- **CloudKit over custom backend** — zero server cost, stays in Apple ecosystem, automatic conflict resolution
- **@Observable over ObservableObject** — eliminates re-render over-firing, no `@Published` noise, cleaner syntax
- **Feature-first structure** — keeps related View/ViewModel/Model together, easier to navigate as the app grows
