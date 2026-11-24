/// Input timestamps are signed microseconds on the song timeline.
public enum InputEvent: Codable, Equatable, Sendable {
    case touchDown(id: Int, lane: Int, time: Int64)
    case touchUp(id: Int, time: Int64)
    case activateHype(time: Int64)

    public var time: Int64 {
        switch self {
        case .touchDown(_, _, let time), .touchUp(_, let time), .activateHype(let time):
            time
        }
    }

    func at(_ time: Int64) -> InputEvent {
        switch self {
        case .touchDown(let id, let lane, _): .touchDown(id: id, lane: lane, time: time)
        case .touchUp(let id, _): .touchUp(id: id, time: time)
        case .activateHype: .activateHype(time: time)
        }
    }
}
