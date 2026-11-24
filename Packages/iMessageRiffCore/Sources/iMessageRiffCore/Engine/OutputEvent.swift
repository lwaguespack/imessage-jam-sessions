/// Deterministic engine output. UI and audio consume these events but do not feed them back into scoring.
public enum OutputEvent: Equatable, Sendable {
    public enum Rejection: Equatable, Sendable {
        case touchAlreadyDown
        case unknownTouch
    }

    case hit(time: Int64, noteIndex: Int, judgement: Judgement, offsetMicros: Int64, points: Int64)
    case miss(time: Int64, noteIndex: Int)
    case ghostTap(time: Int64, lane: Int, penalty: GameConfig.GhostTapPenalty)
    case streakChanged(time: Int64, streak: Int)
    case multiplierChanged(time: Int64, multiplier: Int64)
    case hypeCharged(time: Int64, meter: Int64)
    case hypeActivated(time: Int64, expiryTick: Int)
    case hypeExpired(time: Int64)
    case holdStarted(time: Int64, noteIndex: Int, touchID: Int)
    case holdReleased(time: Int64, noteIndex: Int)
    case holdCompleted(time: Int64, noteIndex: Int)
    case inputRejected(time: Int64, touchID: Int, reason: Rejection)
    case runFinished(time: Int64, score: Int64)
}
