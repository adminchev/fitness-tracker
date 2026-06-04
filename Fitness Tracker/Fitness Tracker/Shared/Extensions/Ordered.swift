import Foundation

/// Model types that carry a manual sort position.
protocol Ordered {
    var order: Int { get }
}

extension Array where Element: Ordered {
    /// The elements sorted ascending by their `order`.
    func sortedByOrder() -> [Element] {
        sorted { $0.order < $1.order }
    }
}

extension Exercise: Ordered {}
extension WorkoutSet: Ordered {}
extension TemplateExercise: Ordered {}
