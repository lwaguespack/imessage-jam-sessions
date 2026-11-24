/// The instrument part a chart is written for.
///
/// Raw values are the strings used in chart files and song manifests (plan appendix A and B).
/// Version 1 ships the lead part only; band mode (plan section 2, v1.1) adds the others.
public enum Part: String, CaseIterable, Codable, Sendable {
    case lead
}
