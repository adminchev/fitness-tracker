import Foundation

/// How effort is shown and entered. Stored value is always canonical RPE (0–10,
/// 10 = failure); RIR is just displayed as `10 − RPE` (0 = failure).
enum EffortScale: String, CaseIterable, Identifiable {
    case rpe = "RPE"
    case rir = "RIR"
    var id: String { rawValue }

    /// Canonical RPE → the value shown for this scale (RIR mirrors around 10).
    func display(_ rpe: Double) -> Double { self == .rir ? 10 - rpe : rpe }

    /// A value shown for this scale → canonical RPE for storage. Inverse of `display`.
    func canonical(_ shown: Double) -> Double { self == .rir ? 10 - shown : shown }
}

/// How the per-set logging controls are drawn. `ExerciseFocusView` reads the
/// resolved value and renders either the standard paged row logger or the
/// accessible guided stepper flow.
enum LogLayout: String, CaseIterable, Identifiable {
    case standard = "Standard"
    case accessible = "Accessible"
    var id: String { rawValue }

    var label: String {
        switch self {
        case .standard: "Standard"
        case .accessible: "Accessible"
        }
    }

    /// One-line explanation shown under the Settings picker.
    var detail: String {
        switch self {
        case .standard: "Dense rows — tap a field and type."
        case .accessible: "One giant control at a time, hard to mistap."
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
        LogLayout(rawValue: UserDefaults.standard.string(forKey: logLayoutKey) ?? "") ?? .standard
    }
}
