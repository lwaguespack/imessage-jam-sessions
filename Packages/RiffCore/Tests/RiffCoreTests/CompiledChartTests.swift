import RiffCore
import Testing

@Suite("Compiled chart")
struct CompiledChartTests {
    /// 120 BPM for 4 beats, then 128 BPM, with two holds, a chord and two Hype phrases.
    private func chart(_ difficulty: Difficulty, tempo: [TempoSegment]? = nil) -> Chart {
        let twoTempos = [TempoSegment(tick: 0, mbpm: 120_000), TempoSegment(tick: 768, mbpm: 128_000)]
        return Chart(
            songId: "test-song",
            part: .lead,
            difficulty: difficulty,
            lanes: 4,
            resolution: 192,
            tempo: tempo ?? twoTempos,
            timeSignatures: [TimeSignature(tick: 0, numerator: 4, denominator: 4)],
            notes: [
                Note(tick: 0, lane: 0),
                Note(tick: 192, lane: 1),
                Note(tick: 576, lane: 2, length: 384),
                Note(tick: 768, lane: 0),
                Note(tick: 960, lane: 1, length: 192),
                Note(tick: 1152, lane: 0),
                Note(tick: 1152, lane: 3),
            ],
            hype: [HypePhrase(start: 0, end: 576), HypePhrase(start: 768, end: 1152)],
            sections: [],
            computed: ChartComputed(
                rulesVersion: 0, noteCount: 0, baseScore: 0, maxScore: 0, starCutoffs: [], hash: "")
        )
    }

    @Test("Notes keep the chart's order and get the time of their tick")
    func noteTimes() throws {
        let compiled = try CompiledChart(chart: chart(.expert), config: .standard)
        #expect(compiled.difficulty == .expert)
        #expect(compiled.tempoMap.segments.map(\.startTime) == [0, 2_000_000])
        #expect(compiled.notes.map(\.lane) == [0, 1, 2, 0, 1, 0, 3])
        #expect(compiled.notes.map(\.tick) == [0, 192, 576, 768, 960, 1152, 1152])
        let times: [Int64] = [0, 500_000, 1_500_000, 2_000_000, 2_468_750, 2_937_500, 2_937_500]
        #expect(compiled.notes.map(\.time) == times)
    }

    @Test("A hold ends at its head tick plus its length; a tap has no end")
    func holdEnds() throws {
        let compiled = try CompiledChart(chart: chart(.expert), config: .standard)
        let endTicks: [Int?] = [nil, nil, 960, nil, 1152, nil, nil]
        let endTimes: [Int64?] = [nil, nil, 2_468_750, nil, 2_937_500, nil, nil]
        #expect(compiled.notes.map(\.endTick) == endTicks)
        #expect(compiled.notes.map(\.endTime) == endTimes)
    }

    @Test("The miss deadline is the note's time plus the difficulty's Good window", arguments: Difficulty.allCases)
    func missDeadlines(difficulty: Difficulty) throws {
        let compiled = try CompiledChart(chart: chart(difficulty), config: .standard)
        let goodWindow: Int64 = difficulty == .easy ? 156_000 : 130_000
        #expect(compiled.notes.allSatisfy { $0.missDeadline == $0.time + goodWindow })
        #expect(compiled.notes[3].missDeadline == 2_000_000 + goodWindow)
    }

    // The hold at tick 576 starts on the first phrase's end and runs into the second: it belongs to neither.
    @Test("A note belongs to the phrase its head tick is in, and a phrase's end tick is outside the phrase")
    func phraseMembership() throws {
        let compiled = try CompiledChart(chart: chart(.expert), config: .standard)
        let phraseIndices: [Int?] = [0, 0, nil, 1, 1, nil, nil]
        #expect(compiled.notes.map(\.phraseIndex) == phraseIndices)
        #expect(compiled.phrases.map(\.startTick) == [0, 768])
        #expect(compiled.phrases.map(\.endTick) == [576, 1152])
        #expect(compiled.phrases.map(\.noteIndices) == [[0, 1], [3, 4]])
    }

    @Test("A chart whose tempo list cannot make a map does not compile")
    func invalidTempo() {
        #expect(throws: TempoMap.Invalid.noSegments) {
            try CompiledChart(chart: chart(.expert, tempo: []), config: .standard)
        }
    }
}
