/// Tracks one saved run through staging, sending and confirmation.
public struct MatchSubmission: Codable, Equatable, Sendable {
    public enum State: String, Codable, Equatable, Sendable {
        case played
        case staged
        case sending
        case confirmed
    }

    public enum Error: Swift.Error, Equatable, Sendable {
        case invalidTransition
    }

    public private(set) var state: State = .played

    public init() {}

    public mutating func staged() throws {
        guard state == .played || state == .staged else { throw Error.invalidTransition }
        state = .staged
    }

    public mutating func startedSending() throws {
        guard state != .confirmed else { throw Error.invalidTransition }
        state = .sending
    }

    public mutating func cancelled() {
        if state == .staged || state == .sending { state = .played }
    }

    /// Only a non-pending message containing the entry confirms the submission.
    public mutating func observe(isPending: Bool, containsEntry: Bool) {
        if containsEntry && !isPending {
            state = .confirmed
        } else if containsEntry && isPending && state == .played {
            state = .staged
        } else if !containsEntry && !isPending && (state == .staged || state == .sending) {
            state = .played
        }
    }
}
