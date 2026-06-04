Review the current working tree diff (`git diff HEAD`) against the conventions defined in CLAUDE.md and report any violations.

Check for each of the following and list any violations found, with the file name and line number:

**Architecture violations**
- [ ] `@ObservableObject` used anywhere (should be `@Observable`)
- [ ] `@StateObject` or `@ObservedObject` used (should be `@State`)
- [ ] `@Published` used (not needed with `@Observable`)
- [ ] Business logic or data fetching inside a View's `body` or View methods
- [ ] SwiftData `@Query` used in a View (fetch in ViewModel instead)
- [ ] ViewModel importing SwiftUI (should only import Foundation + SwiftData)

**SwiftData / CloudKit violations**
- [ ] `@Model` property with no default value and not optional
- [ ] `@Relationship` without a `deleteRule`
- [ ] `@Attribute(.unique)` used on any model property
- [ ] CoreData APIs used (`NSManagedObject`, `NSPersistentContainer`, etc.)

**Swift conventions**
- [ ] Force unwrap (`!`) outside of a test file
- [ ] Type name not UpperCamelCase
- [ ] View not suffixed `View`
- [ ] ViewModel not suffixed `ViewModel`

**UIKit / legacy**
- [ ] Any `UIKit` import
- [ ] Any `Combine` import

For each violation, explain what is wrong and what the correct pattern is (referencing CLAUDE.md).
If no violations are found, say "No convention violations found."
