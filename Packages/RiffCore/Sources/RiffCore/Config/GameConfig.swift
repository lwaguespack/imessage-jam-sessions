/// Every tunable number in the game, in one value (plan 12.2).
///
/// The property defaults in each group are the plan's starting values, so `standard` is the plan as written.
/// Time is whole microseconds (`Int64`) and every ratio is a whole percentage, basis-point count or explicit
/// fraction, never floating point, so a run scores bit-identically on every device.
///
/// To try other values, copy `standard` and change fields. Nothing outside this type may hard-code a number
/// that a playtest could change.
public struct GameConfig: Codable, Equatable, Sendable {
    /// Lanes, on-screen geometry and note travel times (plan 4.1, 4.2).
    public var highway = Highway()

    /// Timing windows, points and accuracy weights per judgement (plan 4.3).
    public var judging = Judging()

    /// Streak multiplier and sustain points (plan 4.4).
    public var scoring = Scoring()

    /// The Hype meter (plan 4.5).
    public var hype = Hype()

    /// Star thresholds and the Gold rule (plan 4.6).
    public var stars = Stars()

    /// Lead-in, countdowns, the miss duck and clock drift (plan 4.7, 4.8, 7.3).
    public var playback = Playback()

    /// Limits on the match payload carried in a message (plan 5.5, appendix C).
    public var payload = Payload()

    /// XP awarded per run (plan 6.1).
    public var xp = XP()

    /// The level curve (plan 6.2).
    public var levels = Levels()

    /// Cosmetic unlock counts (plan 6.3).
    public var unlocks = Unlocks()

    /// Chart format constants and the per-difficulty chart rules (plan 8.4, appendix A).
    public var charts = Charts()

    /// Requirements on song source material (plan 8.2).
    public var songs = Songs()

    /// Performance budgets the app is measured against (plan 7.4).
    public var budgets = Budgets()

    /// The plan's starting values.
    public static let standard = GameConfig()
}
