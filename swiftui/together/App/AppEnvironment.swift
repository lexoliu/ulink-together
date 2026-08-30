import Foundation

enum AppEnvironment {
    /// The Info.plist key queried when the app is built with a baked-in
    /// production server address (e.g. the school's ISMAS deployment).
    static let infoKey = "TOGETHER_API_BASE_URL"

    /// Process-level environment variable consulted as a fallback. Xcode
    /// scheme → Run → Environment Variables writes into this, which is
    /// how the Criterion D recording setup pins the simulator to the
    /// developer's local server without editing the Xcode project.
    static let environmentKey = "TOGETHER_API_BASE_URL"

    static var hasBundledServerURL: Bool {
        bundledServerURL() != nil
    }

    static func bundledServerURL() -> String? {
        // Info.plist takes precedence because a release build that ships
        // with a pre-configured address should never be silently overridden
        // by a stray environment variable on the host machine.
        if let value = Bundle.main.object(forInfoDictionaryKey: infoKey) as? String,
           value.isEmpty == false {
            return value
        }

        // Scheme-level environment variable fallback — used during
        // development and while recording the Criterion D demo.
        if let value = ProcessInfo.processInfo.environment[environmentKey],
           value.isEmpty == false {
            return value
        }

        return nil
    }
}
