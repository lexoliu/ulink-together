import Foundation

enum AppEnvironment {
    static let infoKey = "TOGETHER_API_BASE_URL"
    static let fallbackServerURL = "http://127.0.0.1:8000"

    static func bundledServerURL() -> String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: infoKey) as? String,
              value.isEmpty == false else {
            return fallbackServerURL
        }
        return value
    }
}
