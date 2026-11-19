/// One way a chart breaks the rules in CHART_FORMAT section 4.
public struct ChartIssue: Equatable, Sendable {
    /// The rule that is broken: the structure rules first, then the content rules.
    public enum Rule: String, Sendable {
        case format, songId, lanes, resolution, tempoList, tempoRange, noteTick, noteLane, holdLength, noteOrder
        case chordSize, phraseRange, phraseOrder

        case noteSpan, averageDensity, peakDensity, chordShare, chordSpacing, noteDuringHold, sameLaneGap
        case crossLaneGap, contacts, holdTooShort, phraseCount, phraseMembers, phraseTail, hypeCapacity
        case manifestSong, manifestDuration, songLength
    }

    public let rule: Rule

    /// Where the problem is, for a rule that has a place.
    public let tick: Int?
    public let lane: Int?

    /// One sentence for the person fixing the chart.
    public let message: String

    init(_ rule: Rule, tick: Int? = nil, lane: Int? = nil, _ message: String) {
        self.rule = rule
        self.tick = tick
        self.lane = lane
        self.message = message
    }
}
