Add a new SwiftData model named "$ARGUMENTS" to the fitness tracker app.

Follow these steps exactly:

1. Create `Shared/Persistence/$ARGUMENTS.swift` with a `@Model final class`:
   - Every stored property must be **optional or have a default value** (CloudKit requirement — no exceptions)
   - Every `@Relationship` must specify `deleteRule: .cascade` or `deleteRule: .nullify`
   - Do NOT use `@Attribute(.unique)` — CloudKit does not support unique constraints
   - Include a no-argument initializer with sensible defaults

   Example structure:
   ```swift
   import Foundation
   import SwiftData

   @Model final class $ARGUMENTS {
       var createdAt: Date = Date()
       var name: String = ""
       // add your properties here — all must have defaults or be optional
   }
   ```

2. Open `Shared/Persistence/PersistenceController.swift` and add `$ARGUMENTS.self` to the `ModelContainer` schema array.

3. If this model has a relationship to an existing model, add the inverse relationship in the existing model file too.

Do NOT use CoreData APIs, NSManagedObject, or any non-SwiftData persistence. Do NOT add non-optional stored properties without defaults.
