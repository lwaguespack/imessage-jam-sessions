/// A chart's notes with their times worked out, for the rules that are stated in milliseconds.
struct ChartTimeline {
    let chart: Chart

    /// Song time of each note's tick, in the chart's note order.
    let headTimes: [Int64]

    /// The tick each note ends on: its own tick for a tap.
    let endTicks: [Int]

    let endTimes: [Int64]

    init(chart: Chart, map: TempoMap) {
        self.chart = chart
        headTimes = chart.notes.map { map.time(ofTick: $0.tick) }
        endTicks = chart.notes.map { $0.tick + ($0.length ?? 0) }
        endTimes = endTicks.map { map.time(ofTick: $0) }
    }
}

extension ChartValidator {
    /// A count of notes times this equals thousandths of a note per second times microseconds.
    private static let densityScale: Int64 = 1_000_000_000

    static func densityIssues(
        _ timeline: ChartTimeline, rule: GameConfig.ChartRule, config: GameConfig
    ) -> [ChartIssue] {
        let notes = timeline.chart.notes
        guard let first = timeline.headTimes.first, let last = timeline.headTimes.last, first < last else {
            return [ChartIssue(.noteSpan, "a chart needs notes on at least two ticks")]
        }
        var issues: [ChartIssue] = []
        let span = last - first
        let weight = Int64(notes.count) * densityScale
        let lowest = Int64(rule.minAverageMilliNotesPerSecond)
        let highest = Int64(rule.maxAverageMilliNotesPerSecond)
        if weight < lowest * span || weight > highest * span {
            let message =
                "the average is \(weight / span) thousandths of a note per second, outside \(lowest) to \(highest)"
            issues.append(ChartIssue(.averageDensity, message))
        }

        let window = config.charts.peakWindowMicros
        var busiest = (count: 0, start: 0)
        var end = 0
        for start in notes.indices {
            while end < notes.count && timeline.headTimes[end] < timeline.headTimes[start] + window {
                end += 1
            }
            if end - start > busiest.count {
                busiest = (end - start, start)
            }
        }
        if Int64(busiest.count) * densityScale > Int64(rule.maxPeakMilliNotesPerSecond) * window {
            let message = "\(busiest.count) notes start within \(window / 1_000) ms from this tick"
            issues.append(ChartIssue(.peakDensity, tick: notes[busiest.start].tick, message))
        }
        return issues
    }

    static func chordIssues(_ timeline: ChartTimeline, rule: GameConfig.ChartRule) -> [ChartIssue] {
        let notes = timeline.chart.notes
        // Ticks that hold more than one note, ascending.
        var chordTicks: [Int] = []
        var chordNotes = 0
        for (previous, note) in zip(notes, notes.dropFirst()) where previous.tick == note.tick {
            if chordTicks.last != note.tick {
                chordTicks.append(note.tick)
                chordNotes += 1
            }
            chordNotes += 1
        }
        var issues: [ChartIssue] = []
        if chordNotes * 100 > rule.maxChordNoteSharePercent * notes.count {
            let message =
                "\(chordNotes) of \(notes.count) notes are in chords; at most \(rule.maxChordNoteSharePercent)% may be"
            issues.append(ChartIssue(.chordShare, tick: chordTicks.first, message))
        }
        let spacing = rule.minBeatsBetweenChords * timeline.chart.resolution
        for (previous, tick) in zip(chordTicks, chordTicks.dropFirst()) where tick - previous < spacing {
            let message = "chords must be at least \(rule.minBeatsBetweenChords) beat(s) apart"
            issues.append(ChartIssue(.chordSpacing, tick: tick, message))
        }
        return issues
    }

    static func gapIssues(_ timeline: ChartTimeline, rule: GameConfig.ChartRule) -> [ChartIssue] {
        let notes = timeline.chart.notes
        var issues: [ChartIssue] = []
        // Where the latest-ending note seen so far in each lane ends.
        var laneEnds = [(tick: Int, time: Int64)?](repeating: nil, count: timeline.chart.lanes)
        for (index, note) in notes.enumerated() {
            let time = timeline.headTimes[index]
            if let end = laneEnds[note.lane] {
                if note.tick < end.tick {
                    let message = "a note starts while a hold in its lane is still running"
                    issues.append(ChartIssue(.noteDuringHold, tick: note.tick, lane: note.lane, message))
                } else if time - end.time < rule.minSameLaneGapMicros {
                    let message =
                        "\((time - end.time) / 1_000) ms after the last note in this lane ended; "
                        + "at least \(rule.minSameLaneGapMicros / 1_000) ms is needed"
                    issues.append(ChartIssue(.sameLaneGap, tick: note.tick, lane: note.lane, message))
                }
            }
            if (laneEnds[note.lane]?.tick ?? -1) < timeline.endTicks[index] {
                laneEnds[note.lane] = (timeline.endTicks[index], timeline.endTimes[index])
            }
            if index > 0, notes[index - 1].tick != note.tick,
                time - timeline.headTimes[index - 1] < rule.minCrossLaneGapMicros
            {
                let message =
                    "\((time - timeline.headTimes[index - 1]) / 1_000) ms after the tick before; "
                    + "at least \(rule.minCrossLaneGapMicros / 1_000) ms is needed"
                issues.append(ChartIssue(.crossLaneGap, tick: note.tick, message))
            }
        }
        return issues
    }

    static func contactIssues(_ timeline: ChartTimeline, rule: GameConfig.ChartRule) -> [ChartIssue] {
        let notes = timeline.chart.notes
        var issues: [ChartIssue] = []
        // End ticks of the holds that started before the tick being looked at and are still running.
        var liveEnds: [Int] = []
        var index = 0
        while index < notes.count {
            let tick = notes[index].tick
            var next = index
            while next < notes.count && notes[next].tick == tick {
                next += 1
            }
            liveEnds.removeAll { $0 <= tick }
            let contacts = liveEnds.count + (next - index)
            if contacts > rule.maxSimultaneousContacts {
                let message =
                    "\(contacts) fingers are needed at once; at most \(rule.maxSimultaneousContacts) are allowed"
                issues.append(ChartIssue(.contacts, tick: tick, message))
            }
            for held in index..<next where notes[held].length != nil {
                liveEnds.append(timeline.endTicks[held])
            }
            index = next
        }
        return issues
    }

    static func holdIssues(_ timeline: ChartTimeline, rule: GameConfig.ChartRule, config: GameConfig) -> [ChartIssue] {
        let shortest = rule.shortestHold
        let shortestMillis = config.charts.minHoldMicros / 1_000
        var issues: [ChartIssue] = []
        for (index, note) in timeline.chart.notes.enumerated() {
            guard let length = note.length else { continue }
            let longEnoughInBeats = length * shortest.denominator >= timeline.chart.resolution * shortest.numerator
            let duration = timeline.endTimes[index] - timeline.headTimes[index]
            if !longEnoughInBeats || duration < config.charts.minHoldMicros {
                let message =
                    "a hold must last at least \(shortest.numerator)/\(shortest.denominator) beat and "
                    + "\(shortestMillis) ms; this one lasts \(length) ticks, \(duration / 1_000) ms"
                issues.append(ChartIssue(.holdTooShort, tick: note.tick, lane: note.lane, message))
            }
        }
        return issues
    }
}
