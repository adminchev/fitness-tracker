import Foundation

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

    /// Unit label for the load field, or nil if the exercise carries no external load.
    var loadUnit: String? {
        switch self {
        case .freeWeight, .cable: "kg"
        case .band: "band"
        case .bodyweight: nil
        }
    }
}

enum SetSide: String, CaseIterable, Identifiable {
    case left = "L"
    case right = "R"
    var id: String { rawValue }
}
