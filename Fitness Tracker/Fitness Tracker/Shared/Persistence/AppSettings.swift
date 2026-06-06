import Foundation

/// How effort is shown and entered. Stored value is always canonical RPE (0–10,
/// 10 = failure); RIR is just displayed as `10 − RPE` (0 = failure).
enum EffortScale: String, CaseIterable, Identifiable {
    case rpe = "RPE"
    case rir = "RIR"
    var id: String { rawValue }
}

/// How the per-set logging controls are drawn. Adding a new layout is a matter of
/// adding a case here and a matching view that `SetRowView` switches to — the rest
/// of the app only ever talks to `SetRowView`.
enum LogLayout: String, CaseIterable, Identifiable {
    case compact = "Compact"
    case bigButtons = "Big buttons"
    var id: String { rawValue }

    var label: String {
        switch self {
        case .compact: "Compact"
        case .bigButtons: "Big buttons"
        }
    }

    /// One-line explanation shown under the Settings picker.
    var detail: String {
        switch self {
        case .compact: "Dense rows — tap a field and type."
        case .bigButtons: "Large +/− steppers, easy to hit mid-set."
        }
    }
}

/// Lightweight user preferences stored in `UserDefaults`. Views bind to these keys
/// with `@AppStorage`; non-view code reads the resolved values here.
enum AppSettings {
    static let leadSideKey = "leadSide"
    static let effortScaleKey = "effortScale"
    static let logLayoutKey = "logLayout"

    /// Which arm is the default tab and is pre-created first for unilateral exercises.
    static var leadSide: SetSide {
        SetSide(rawValue: UserDefaults.standard.string(forKey: leadSideKey) ?? "") ?? .right
    }

    static var effortScale: EffortScale {
        EffortScale(rawValue: UserDefaults.standard.string(forKey: effortScaleKey) ?? "") ?? .rpe
    }

    /// Which set-logging control layout the focused logger renders.
    static var logLayout: LogLayout {
        LogLayout(rawValue: UserDefaults.standard.string(forKey: logLayoutKey) ?? "") ?? .compact
    }
}
