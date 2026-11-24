/// The verdict on a single note (plan 4.3), best first in `allCases`.
public enum Judgement: String, CaseIterable, Codable, Sendable {
    case perfect
    case great
    case good
    case miss
}
