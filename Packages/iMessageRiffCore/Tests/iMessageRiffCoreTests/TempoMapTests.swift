import Testing
import iMessageRiffCore

@Suite("Tempo map")
struct TempoMapTests {
    /// 120 BPM for 4 beats, then 128 BPM: a tick lasts 2,604.17 microseconds, then 2,441.41.
    private func twoTempoMap() throws -> TempoMap {
        try TempoMap(
            resolution: 192,
            tempo: [TempoSegment(tick: 0, mbpm: 120_000), TempoSegment(tick: 768, mbpm: 128_000)]
        )
    }

    /// Three tempos that change off the beat, so every segment start needs rounding.
    private func awkwardMap() throws -> TempoMap {
        try TempoMap(
            resolution: 192,
            tempo: [
                TempoSegment(tick: 0, mbpm: 128_000),
                TempoSegment(tick: 100, mbpm: 90_500),
                TempoSegment(tick: 333, mbpm: 171_717),
            ]
        )
    }

    @Test("Tick times in a two-tempo map match values worked out by hand")
    func timesOfTicks() throws {
        let map = try twoTempoMap()
        let expected: [(tick: Int, time: Int64)] = [
            (-192, -500_000), (-1, -2_604), (0, 0), (1, 2_605), (48, 125_000), (767, 1_997_396),
            (768, 2_000_000), (769, 2_002_442), (960, 2_468_750),
        ]
        for (tick, time) in expected {
            #expect(map.time(ofTick: tick) == time, "tick \(tick)")
        }
    }

    @Test("Times in a two-tempo map fall on the ticks worked out by hand")
    func ticksAtTimes() throws {
        let map = try twoTempoMap()
        let expected: [(time: Int64, tick: Int)] = [
            (-2_605, -2), (-2_604, -1), (-1, -1), (0, 0), (2_604, 0), (2_605, 1), (1_999_999, 767),
            (2_000_000, 768), (2_002_441, 768), (2_002_442, 769), (2_468_750, 960),
        ]
        for (time, tick) in expected {
            #expect(map.tick(atTime: time) == tick, "time \(time)")
        }
    }

    @Test("Each segment starts at the time of its first tick, rounded up")
    func segmentStarts() throws {
        #expect(try twoTempoMap().segments.map(\.startTime) == [0, 2_000_000])

        let awkward = try awkwardMap()
        #expect(awkward.segments.map(\.startTick) == [0, 100, 333])
        #expect(awkward.segments.map(\.startTime) == [0, 244_141, 1_048_700])
        let expected: [(tick: Int, time: Int64)] = [
            (48, 117_188), (99, 241_700), (100, 244_141), (101, 247_595), (332, 1_045_246),
            (333, 1_048_700), (334, 1_050_520),
        ]
        for (tick, time) in expected {
            #expect(awkward.time(ofTick: tick) == time, "tick \(tick)")
        }
    }

    @Test("A tick's time converts back to that tick, and one microsecond earlier to the tick before")
    func ticksRoundTrip() throws {
        for map in try [twoTempoMap(), awkwardMap()] {
            for tick in -400..<1_500 {
                let time = map.time(ofTick: tick)
                #expect(map.tick(atTime: time) == tick, "tick \(tick)")
                #expect(map.tick(atTime: time - 1) == tick - 1, "tick \(tick)")
            }
        }
    }

    @Test("The tick at a time is the last tick whose time is at or before it")
    func tickIsTheLastOneAtOrBefore() throws {
        for map in try [twoTempoMap(), awkwardMap()] {
            for time in stride(from: Int64(-10_000), through: 2_600_000, by: 997) {
                let tick = map.tick(atTime: time)
                #expect(map.time(ofTick: tick) <= time, "time \(time)")
                #expect(map.time(ofTick: tick + 1) > time, "time \(time)")
            }
        }
    }

    // Rounding both conversions down gave 117,187 microseconds, which converted back to tick 47 (D-086).
    @Test("At 128 BPM tick 48 is at 117,188 microseconds and converts back to tick 48")
    func halfMicrosecondRoundsUp() throws {
        let map = try TempoMap(resolution: 192, tempo: [TempoSegment(tick: 0, mbpm: 128_000)])
        #expect(map.time(ofTick: 48) == 117_188)
        #expect(map.tick(atTime: 117_188) == 48)
        #expect(map.tick(atTime: 117_187) == 47)
    }

    @Test("A tempo of exactly one microsecond per tick is accepted, and one step faster is refused")
    func oneMicrosecondPerTickIsTheLimit() throws {
        let fastest = try TempoMap(resolution: 960, tempo: [TempoSegment(tick: 0, mbpm: 62_500_000)])
        #expect(fastest.time(ofTick: 12_345) == 12_345)
        #expect(fastest.tick(atTime: -7) == -7)
        #expect(throws: TempoMap.Invalid.tickShorterThanOneMicrosecond(index: 0)) {
            try TempoMap(resolution: 960, tempo: [TempoSegment(tick: 0, mbpm: 62_500_001)])
        }
    }

    @Test("A tempo list that cannot make a map is refused with the reason")
    func invalidTempoLists() {
        let first = TempoSegment(tick: 0, mbpm: 120_000)
        #expect(throws: TempoMap.Invalid.resolutionNotPositive) {
            try TempoMap(resolution: 0, tempo: [first])
        }
        #expect(throws: TempoMap.Invalid.noSegments) {
            try TempoMap(resolution: 192, tempo: [])
        }
        #expect(throws: TempoMap.Invalid.firstSegmentNotAtTickZero) {
            try TempoMap(resolution: 192, tempo: [TempoSegment(tick: 96, mbpm: 120_000)])
        }
        #expect(throws: TempoMap.Invalid.tempoNotPositive(index: 1)) {
            try TempoMap(resolution: 192, tempo: [first, TempoSegment(tick: 96, mbpm: 0)])
        }
        #expect(throws: TempoMap.Invalid.segmentsNotAscending(index: 1)) {
            try TempoMap(resolution: 192, tempo: [first, TempoSegment(tick: 0, mbpm: 90_000)])
        }
        #expect(throws: TempoMap.Invalid.segmentsNotAscending(index: 2)) {
            let second = TempoSegment(tick: 96, mbpm: 90_000)
            return try TempoMap(resolution: 192, tempo: [first, second, TempoSegment(tick: 96, mbpm: 100_000)])
        }
    }

    // The validator allows at most 300 BPM and resolution 960; 8 hours is far beyond any song.
    @Test("Conversions stay inside Int64 for 8 hours either side of zero at the validator's limits")
    func headroomAtTheLimits() throws {
        let map = try TempoMap(resolution: 960, tempo: [TempoSegment(tick: 0, mbpm: 300_000)])
        let eightHours: Int64 = 8 * 3600 * 1_000_000
        let ticks = 138_240_000
        #expect(map.tick(atTime: eightHours) == ticks)
        #expect(map.time(ofTick: ticks) == eightHours)
        #expect(map.tick(atTime: -eightHours) == -ticks)
        #expect(map.time(ofTick: -ticks) == -eightHours)
    }
}
