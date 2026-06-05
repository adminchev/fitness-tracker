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

### Two view patterns — both are correct; pick by screen type
This project uses **two complementary patterns**. Don't force everything into one.

**1. List / dashboard screens → `@Observable` ViewModel.** Screens that fetch collections own a `@Observable final class …ViewModel` that runs `FetchDescriptor` queries and exposes results. The View holds it with `@State private var viewModel = …` and passes `ModelContext` into its methods. Examples: `WorkoutListView`, `TrainingPlansView`, `ProgressDashboardView`.

**2. Single-model edit screens → observe the `@Model` directly.** Screens that edit one SwiftData object take it as `@Bindable var model: SomeModel` and keep their small mutation helpers in the View — there is **no** ViewModel. Routing a `@Model` through a `let` on an `@Observable` class breaks SwiftData change tracking, so the view must observe the model directly. Examples: `WorkoutDetailView`, `TrainingPlanDetailView`, `ExerciseRowView`, `ExerciseProgressView`.

### Rules
- ViewModels are `@Observable final class`, suffixed `ViewModel`; pass `ModelContext` into methods rather than storing it.
- Views are `struct`. Heavy or pure calculation lives in a dedicated type (e.g. `ProgressCalculator`), never inline in `body`.
- Never use `@ObservableObject` / `@StateObject` / `@Published`, Combine, or UIKit.

---

## Project Structure

The Xcode project lives at `Fitness Tracker/Fitness Tracker/` within the repo root.

```
Fitness Tracker/Fitness Tracker/
  Fitness_TrackerApp.swift     # @main entry point
  ContentView.swift            # Top-level TabView (Workouts / Progress / Plans)
  Features/
    Workout/
      WorkoutListView.swift        # list of sessions (+ debug sample-data menu)
      WorkoutListViewModel.swift   # fetch + create-from-plan + delete
      WorkoutDetailView.swift      # one session: date, exercises, add-exercise
      ExerciseRowView.swift        # one exercise inside a session (L/R tab, sets)
    Plans/
      TrainingPlansView.swift / TrainingPlansViewModel.swift
      TrainingPlanDetailView.swift # edit a plan's exercises
    Progress/
      ProgressDashboardView.swift / ProgressDashboardViewModel.swift  # consistency + exercise list
      ExerciseProgressView.swift   # per-exercise charts (Swift Charts)
      ProgressMetrics.swift        # ProgressCalculator + metric/range enums (pure logic)
  Shared/
    Components/        # Reusable, data-agnostic views
      SetRowView.swift, NumericField.swift, TimedSetField.swift,
      ExercisePickerView.swift, PlanPickerView.swift
    Extensions/
      Ordered.swift                # `sortedByOrder()` for order-bearing models
    Persistence/       # All @Model classes + container + seeding
      Workout.swift, Exercise.swift, WorkoutSet.swift,
      TrainingPlan.swift, TemplateExercise.swift, ExerciseDefinition.swift,
      ExerciseTypes.swift          # Equipment + SetSide enums
      PersistenceController.swift  # ModelContainer (CloudKit) + seed-on-empty
      SeedData.swift               # 3-phase program + catalog (first launch)
      SampleData.swift             # #if DEBUG demo-history generator
```

New features go in `Features/[FeatureName]/`. Reusable UI goes in `Shared/Components/`. Never mix feature logic into Shared.

---

## SwiftData Schema

All `@Model` classes live in `Shared/Persistence/`. The canonical models:

Six models. Relationships always declare an inverse (see rules below). Set fields are
**optional** so empty means "not recorded" (vs. a real 0).

```swift
@Model final class Workout {            // one training session
    var date: Date = Date()
    var name: String = ""
    @Relationship(deleteRule: .nullify) var trainingPlan: TrainingPlan? = nil
    @Relationship(deleteRule: .cascade, inverse: \Exercise.workout) var exercises: [Exercise]? = []
}

@Model final class Exercise {           // one movement within a session
    var name: String = ""
    var order: Int = 0
    var targetSummary: String = ""      // copied from the plan for in-session guidance
    var notes: String = ""
    var isTimed: Bool = false           // holds log seconds instead of reps
    var tracksSides: Bool = false       // unilateral → per-set L/R
    var equipmentRaw: String = …        // Equipment raw value (kg vs band unit)
    var targetRPE: Double? = nil        // prescribed RPE (auto-fills sets, scores adherence)
    var workout: Workout? = nil
    var definition: ExerciseDefinition? = nil
    @Relationship(deleteRule: .cascade, inverse: \WorkoutSet.exercise) var sets: [WorkoutSet]? = []
}

@Model final class WorkoutSet {         // one logged set
    var reps: Int? = nil
    var weight: Double? = nil           // load: kg, or band rating for bands
    var durationSeconds: Int? = nil     // for timed holds
    var rpe: Double? = nil
    var side: String = ""               // "" / SetSide.left.rawValue / .right.rawValue
    var order: Int = 0
    var exercise: Exercise? = nil
}

// Catalog + plan side:
@Model final class ExerciseDefinition   // canonical, reusable exercise (self-populating catalog)
@Model final class TrainingPlan          // a named plan (e.g. "Phase 1")
@Model final class TemplateExercise      // a prescribed exercise in a plan (sets/reps/RPE/rest/notes)
```

`ExerciseDefinition` carries `equipmentRaw`, `isTimed`, `tracksSides`, plus `isSeeded`
(seeded catalog/plan items are protected from deletion). When adding models, follow
this structure: optional/defaulted fields, declared inverses, raw-value enums.

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
- No heavy/pure computation inline in `body` — put it in `ProgressCalculator` or a ViewModel. (Small mutation helpers on single-model edit views are fine — see the two-pattern note above.)

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

## Testing

Unit tests use **Swift Testing** (`@Test` / `#expect`) in the `Fitness TrackerTests` target,
and cover the pure logic: `ProgressCalculator`, prescription parsing, consistency math
(date-injected via a `now:` parameter), and `createWorkout`. Run with ⌘U or:

```bash
xcodebuild test -scheme "Fitness Tracker" -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:"Fitness TrackerTests"
```

Test the math, not the views. Functions that read the clock take an injectable `now:`
so they're deterministic. To explore the UI with realistic data, use the debug-only
🐞 menu on the Workouts tab ("Load sample history").

---

## Key Decisions Log

- **SwiftData over CoreData** — SwiftData is the modern API, less boilerplate, better Swift integration
- **CloudKit over custom backend** — zero server cost, stays in Apple ecosystem, automatic conflict resolution
- **@Observable over ObservableObject** — eliminates re-render over-firing, no `@Published` noise, cleaner syntax
- **Feature-first structure** — keeps related View/ViewModel/Model together, easier to navigate as the app grows
