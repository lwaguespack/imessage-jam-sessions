/// Accuracy is the mean judgement weight, rounded down to whole basis points.
public enum Accuracy {
    public enum Error: Swift.Error, Equatable, Sendable {
        case invalidNoteCount
        case invalidWeightedTotal
        case overflow
    }

    public static func basisPoints(weightedTotal: Int64, noteCount: Int) throws -> Int {
        guard noteCount > 0 else { throw Error.invalidNoteCount }
        let (maximum, overflow) = Int64(noteCount).multipliedReportingOverflow(by: 10_000)
        guard !overflow else { throw Error.overflow }
        guard weightedTotal >= 0, weightedTotal <= maximum else { throw Error.invalidWeightedTotal }
        return Int(weightedTotal / Int64(noteCount))
    }
}
