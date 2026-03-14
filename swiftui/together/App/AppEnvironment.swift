import Foundation

enum AppEnvironment {
    static let infoKey = "TOGETHER_API_BASE_URL"

    static func bundledServerURL() -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: infoKey) as? String,
              value.isEmpty == false else {
            return nil
        }
        return value
    }
}
