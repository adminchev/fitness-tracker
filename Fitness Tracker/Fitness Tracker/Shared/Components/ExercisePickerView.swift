internal import SwiftUI
import SwiftData

/// A searchable, self-populating exercise picker. Filters the catalog as you
/// type (prefix matches rank above substring matches, then by how often the
/// exercise has been logged), and offers to create a new entry when nothing
/// matches exactly.
struct ExercisePickerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var definitions: [ExerciseDefinition] = []
    let onSelect: (ExerciseDefinition) -> Void

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var results: [ExerciseDefinition] {
        guard !trimmedQuery.isEmpty else {
            return definitions.sorted { usage($0) > usage($1) }
        }
        let q = trimmedQuery.lowercased()
        return definitions
            .filter { $0.name.lowercased().contains(q) }
            .sorted { lhs, rhs in
                let l = rank(lhs.name.lowercased(), q)
                let r = rank(rhs.name.lowercased(), q)
                if l != r { return l < r }
                return usage(lhs) > usage(rhs)
            }
    }

    private var exactMatchExists: Bool {
        definitions.contains { $0.name.lowercased() == trimmedQuery.lowercased() }
    }

    var body: some View {
        NavigationStack {
            List {
                if !trimmedQuery.isEmpty && !exactMatchExists {
                    Button {
                        createAndSelect(trimmedQuery)
                    } label: {
                        Label("Create “\(trimmedQuery)”", systemImage: "plus.circle")
                    }
                }
                ForEach(results) { definition in
                    Button {
                        select(definition)
                    } label: {
                        HStack {
                            Text(definition.name)
                                .foregroundStyle(.primary)
                            Spacer()
                            if usage(definition) > 0 {
                                Text("\(usage(definition))×")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        if !definition.isSeeded {
                            Button(role: .destructive) {
                                delete(definition)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: "Search or create an exercise")
            .navigationTitle("Choose Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear(perform: load)
    }

    private func usage(_ definition: ExerciseDefinition) -> Int {
        definition.exercises?.count ?? 0
    }

    private func rank(_ name: String, _ query: String) -> Int {
        if name == query { return 0 }
        if name.hasPrefix(query) { return 1 }
        return 2
    }

    private func load() {
        let descriptor = FetchDescriptor<ExerciseDefinition>(sortBy: [SortDescriptor(\.name)])
        definitions = (try? modelContext.fetch(descriptor)) ?? []
    }

    private func select(_ definition: ExerciseDefinition) {
        onSelect(definition)
        dismiss()
    }

    private func createAndSelect(_ name: String) {
        let definition = ExerciseDefinition(name: name)
        modelContext.insert(definition)
        onSelect(definition)
        dismiss()
    }

    private func delete(_ definition: ExerciseDefinition) {
        guard !definition.isSeeded else { return }
        modelContext.delete(definition)
        load()
    }
}
