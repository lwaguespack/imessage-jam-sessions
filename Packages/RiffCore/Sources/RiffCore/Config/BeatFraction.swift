/// A length in beats as an exact fraction, for values such as "1/4 beat" that have no whole-number form.
///
/// Stored as written, not reduced, so the config reads like the plan's tables. Compare two fractions by
/// cross-multiplying rather than with `==`, which treats 1/2 and 2/4 as different.
public struct BeatFraction: Codable, Equatable, Sendable {
    public var numerator: Int
    public var denominator: Int

    public init(_ numerator: Int, _ denominator: Int) {
        self.numerator = numerator
        self.denominator = denominator
    }
}
