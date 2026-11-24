/// Version constants for the package and for the formats it reads and writes.
///
/// The type is not called `iMessageRiffCore` on purpose: a type that shares the module's name makes a qualified
/// reference such as `iMessageRiffCore.GameConfig` resolve against the type instead of the module.
public enum IMessageRiffCoreInfo {
    /// Package version. Keep equal to `MARKETING_VERSION` in `Config/Base.xcconfig`; a test compares the two.
    public static let version = "0.1.0"

    /// Version of the match payload schema (plan 5.5, appendix C).
    public static let payloadSchemaVersion = 2

    /// Version of the chart file format (plan appendix A).
    public static let chartSchemaVersion = 1
}
