/// Chart difficulty, easiest first in `allCases`.
///
/// Raw values are the strings used in chart files and song manifests (plan appendix A and B).
public enum Difficulty: String, CaseIterable, Codable, Sendable {
    case easy
    case medium
    case hard
    case expert
}
