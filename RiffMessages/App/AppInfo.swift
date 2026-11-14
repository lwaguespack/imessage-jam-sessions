import Foundation

/// Values read from the extension's Info.plist, so the code name lives in one build setting.
enum AppInfo {
    static var displayName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "Riff"
    }

    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }
}
