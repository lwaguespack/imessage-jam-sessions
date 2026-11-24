/// One value for each difficulty.
///
/// A struct rather than a dictionary so that a difficulty can never be missing: lookups are total, and the JSON
/// form is an object whose keys are the `Difficulty` raw values, all four required.
public struct PerDifficulty<Value: Codable & Equatable & Sendable>: Codable, Equatable, Sendable {
    public var easy: Value
    public var medium: Value
    public var hard: Value
    public var expert: Value

    public init(easy: Value, medium: Value, hard: Value, expert: Value) {
        self.easy = easy
        self.medium = medium
        self.hard = hard
        self.expert = expert
    }

    public subscript(difficulty: Difficulty) -> Value {
        switch difficulty {
        case .easy: easy
        case .medium: medium
        case .hard: hard
        case .expert: expert
        }
    }
}
