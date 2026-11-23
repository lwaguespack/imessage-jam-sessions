/// Phrase charging and tick-based Hype drain, independent of frame rate and wall clocks.
public struct HypeMeter: Sendable {
    public enum Error: Swift.Error, Equatable, Sendable {
        case invalidConfiguration
        case invalidNoteIndex(Int)
        case noteAlreadyJudged(Int)
        case timeMovedBackwards
        case overdueExpiry
        case prematureExpiry
        case overflow
    }

    private let phraseForNote: [Int?]
    private let capacity: Int64
    private let gain: Int64
    private let activationMinimum: Int64
    private let drainPerTick: Int64
    private var remaining: [Int]
    private var failed: [Bool]
    private var judged: [Bool]

    public private(set) var currentTick: Int
    public private(set) var meter: Int64 = 0
    public private(set) var isActive = false
    public private(set) var expiryTick: Int?

    public init(chart: CompiledChart, config: GameConfig, initialTick: Int) throws {
        let resolution = chart.tempoMap.resolution
        guard
            resolution > 0, config.hype.meterCapacity > 0, config.hype.phraseGain > 0,
            config.hype.activationMinimum > 0, config.hype.drainPerBeat > 0
        else { throw Error.invalidConfiguration }
        let capacity = try Self.units(config.hype.meterCapacity, resolution: resolution)
        let gain = try Self.units(config.hype.phraseGain, resolution: resolution)
        let minimum = try Self.units(config.hype.activationMinimum, resolution: resolution)
        guard minimum <= capacity else { throw Error.invalidConfiguration }
        self.capacity = capacity
        self.gain = gain
        activationMinimum = minimum
        drainPerTick = Int64(config.hype.drainPerBeat)
        phraseForNote = chart.notes.map(\.phraseIndex)
        remaining = chart.phrases.map { $0.noteIndices.count }
        failed = [Bool](repeating: false, count: chart.phrases.count)
        judged = [Bool](repeating: false, count: chart.notes.count)
        currentTick = initialTick
    }

    /// Drains through a tick, but expiry itself remains pending until its ordered event is processed.
    public mutating func advance(toTick tick: Int) throws {
        guard tick >= currentTick else { throw Error.timeMovedBackwards }
        let (difference, overflow) = tick.subtractingReportingOverflow(currentTick)
        guard !overflow else { throw Error.overflow }
        if isActive, let expiryTick {
            guard tick <= expiryTick else { throw Error.overdueExpiry }
            if tick == expiryTick {
                meter = 0
            } else {
                let (drained, drainOverflow) = Int64(difference).multipliedReportingOverflow(by: drainPerTick)
                guard !drainOverflow, drained <= meter else { throw Error.overflow }
                meter -= drained
            }
        }
        currentTick = tick
    }

    /// Returns true only when this judgement completes an unfailed phrase and charges the meter.
    public mutating func noteJudged(noteIndex: Int, judgement: Judgement) throws -> Bool {
        guard judged.indices.contains(noteIndex) else { throw Error.invalidNoteIndex(noteIndex) }
        guard !judged[noteIndex] else { throw Error.noteAlreadyJudged(noteIndex) }
        guard let phrase = phraseForNote[noteIndex] else {
            judged[noteIndex] = true
            return false
        }
        let completes = remaining[phrase] == 1 && !failed[phrase] && judgement != .miss
        var newMeter = meter
        var newExpiry = expiryTick
        if completes {
            newMeter += min(gain, capacity - meter)
            if isActive { newExpiry = try expiry(from: currentTick, meter: newMeter) }
        }
        judged[noteIndex] = true
        remaining[phrase] -= 1
        if judgement == .miss { failed[phrase] = true }
        meter = newMeter
        expiryTick = newExpiry
        return completes
    }

    /// Returns false for an activation while active or below the threshold.
    public mutating func activate() throws -> Bool {
        guard !isActive, meter >= activationMinimum else { return false }
        let end = try expiry(from: currentTick, meter: meter)
        isActive = true
        expiryTick = end
        return true
    }

    /// Returns false for an obsolete scheduled expiry, such as one extended by a phrase.
    public mutating func expire(expectedTick: Int) throws -> Bool {
        guard isActive, expiryTick == expectedTick else { return false }
        guard currentTick == expectedTick, meter == 0 else { throw Error.prematureExpiry }
        isActive = false
        expiryTick = nil
        return true
    }

    private func expiry(from tick: Int, meter: Int64) throws -> Int {
        let duration = meter / drainPerTick + (meter.isMultiple(of: drainPerTick) ? 0 : 1)
        guard let delta = Int(exactly: duration) else { throw Error.overflow }
        let (result, overflow) = tick.addingReportingOverflow(delta)
        guard !overflow else { throw Error.overflow }
        return result
    }

    private static func units(_ beats: Int, resolution: Int) throws -> Int64 {
        let (result, overflow) = Int64(beats).multipliedReportingOverflow(by: Int64(resolution))
        guard !overflow else { throw Error.overflow }
        return result
    }
}
