enum IntegerMath {
    /// Division toward minus infinity; the divisor must be positive.
    static func floorDivide(_ dividend: Int64, by divisor: Int64) -> Int64 {
        let quotient = dividend / divisor
        return dividend % divisor < 0 ? quotient - 1 : quotient
    }
}
