import Foundation

/// How effort is shown and entered. Stored value is always canonical RPE (0–10,
/// 10 = failure); RIR is just displayed as `10 − RPE` (0 = failure).
enum EffortScale: String, CaseIterable, Identifiable {
    case rpe = "RPE"
    case rir = "RIR"
    var id: String { rawValue }
}

/// Lightweight user preferences stored in `UserDefaults`. Views bind to these keys
/// with `@AppStorage`; non-view code reads the resolved values here.
enum AppSettings {
    static let leadSideKey = "leadSide"
    static let effortScaleKey = "effortScale"

    /// Which arm is the default tab and is pre-created first for unilateral exercises.
    static var leadSide: SetSide {
        SetSide(rawValue: UserDefaults.standard.string(forKey: leadSideKey) ?? "") ?? .right
    }

    static var effortScale: EffortScale {
        EffortScale(rawValue: UserDefaults.standard.string(forKey: effortScaleKey) ?? "") ?? .rpe
    }
}
