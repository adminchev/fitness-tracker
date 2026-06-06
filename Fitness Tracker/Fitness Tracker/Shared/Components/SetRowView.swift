internal import SwiftUI
import SwiftData

/// One set's input row. This is the single entry point the logger uses; it picks the
/// concrete control layout from the user's Settings choice and forwards everything to
/// it. To add a new layout: add a `LogLayout` case and a view, then a `case` below.
struct SetRowView: View {
    @Bindable var set: WorkoutSet
    let setNumber: Int
    var isTimed: Bool = false
    var equipment: Equipment = .freeWeight
    var weightSuggestions: [Double] = []
    var repSuggestions: [Double] = []
    @AppStorage(AppSettings.logLayoutKey) private var layoutRaw = LogLayout.compact.rawValue

    private var layout: LogLayout { LogLayout(rawValue: layoutRaw) ?? .compact }

    var body: some View {
        switch layout {
        case .compact:
            CompactSetRow(set: set, setNumber: setNumber, isTimed: isTimed, equipment: equipment,
                          weightSuggestions: weightSuggestions, repSuggestions: repSuggestions)
        case .bigButtons:
            BigButtonSetRow(set: set, setNumber: setNumber, isTimed: isTimed, equipment: equipment,
                            weightSuggestions: weightSuggestions, repSuggestions: repSuggestions)
        }
    }
}
