import Foundation

enum AppEnvironment {
    static let infoKey = "TOGETHER_API_BASE_URL"

    static func bundledServerURL() -> String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: infoKey) as? String else {
            preconditionFailure("Missing \(infoKey) in Info.plist build settings.")
        }
        return value
    }
}
