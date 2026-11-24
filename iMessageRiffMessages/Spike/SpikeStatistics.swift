import Foundation

enum SpikeStatistics {
    static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }
        return sorted[middle]
    }

    static func percentile(_ values: [Double], fraction: Double) -> Double? {
        guard !values.isEmpty, (0...1).contains(fraction) else { return nil }
        let sorted = values.sorted()
        let index = max(0, Int(ceil(fraction * Double(sorted.count))) - 1)
        return sorted[index]
    }

    static func robustSpread(_ values: [Double]) -> Double? {
        guard let middle = median(values) else { return nil }
        return median(values.map { abs($0 - middle) }).map { $0 * 1.4826 }
    }
}
