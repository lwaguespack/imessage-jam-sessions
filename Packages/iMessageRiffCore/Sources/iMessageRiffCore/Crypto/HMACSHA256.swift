/// HMAC-SHA256 (RFC 2104), written out because CryptoKit does not exist on Linux.
public enum HMACSHA256 {
    /// The 32-byte authentication code of `message` under `key`.
    public static func authenticationCode(for message: [UInt8], key: [UInt8]) -> [UInt8] {
        var block = key.count > SHA256.blockLength ? SHA256.hash(key) : key
        block += [UInt8](repeating: 0, count: SHA256.blockLength - block.count)
        let inner = SHA256.hash(block.map { $0 ^ 0x36 } + message)
        return SHA256.hash(block.map { $0 ^ 0x5c } + inner)
    }
}
