/// Integer star thresholds and the Full Combo Gold rule.
public enum StarRating {
    public enum Error: Swift.Error, Equatable, Sendable {
        case invalidBaseScore
        case invalidScore
        case invalidShares
        case invalidGoldRule
        case overflow
    }

    public static func cutoffs(baseScore: Int64, shares: [Int]) throws -> [Int64] {
        guard baseScore > 0 else { throw Error.invalidBaseScore }
        guard shares.count == 5, shares.allSatisfy({ (1...100).contains($0) }),
            zip(shares, shares.dropFirst()).allSatisfy({ $0 < $1 })
        else { throw Error.invalidShares }
        return try shares.map { share in
            let (product, overflow) = baseScore.multipliedReportingOverflow(by: Int64(share))
            guard !overflow else { throw Error.overflow }
            return product / 100 + (product.isMultiple(of: 100) ? 0 : 1)
        }
    }

    public static func value(
        score: Int64, baseScore: Int64, fullCombo: Bool, difficulty: Difficulty, config: GameConfig.Stars
    ) throws -> Int {
        guard score >= 0 else { throw Error.invalidScore }
        guard (1...5).contains(config.goldMinimumStars), config.goldStarValue > 5 else {
            throw Error.invalidGoldRule
        }
        let thresholds = try cutoffs(baseScore: baseScore, shares: config.sharesPercent[difficulty])
        let stars = thresholds.filter { score >= $0 }.count
        return fullCombo && stars >= config.goldMinimumStars ? config.goldStarValue : stars
    }
}
