import Foundation

/// What a movement is loaded with. Drives the unit shown on the set's load field
/// (kg vs a band rating) and whether a load field is shown at all.
enum Equipment: String, CaseIterable, Identifiable {
    case freeWeight
    case band
    case bodyweight
    case cable
    var id: String { rawValue }

    var label: String {
        switch self {
        case .freeWeight: "Free weight"
        case .band: "Band"
        case .bodyweight: "Bodyweight"
        case .cable: "Cable"
        }
    }

    /// Unit label for the load field, or `nil` for bodyweight (no external load).
    var loadUnit: String? {
        switch self {
        case .freeWeight, .cable: "kg"
        case .band: "band"
        case .bodyweight: nil
        }
    }
}

/// Which arm a set belongs to, for unilateral exercises. Stored on `WorkoutSet`
/// as its raw value ("L" / "R") because CloudKit can't persist a bare enum.
enum SetSide: String, CaseIterable, Identifiable {
    case left = "L"
    case right = "R"
    var id: String { rawValue }
}
