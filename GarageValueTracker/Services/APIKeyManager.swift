import Foundation
import Security

class APIKeyManager {
    static let shared = APIKeyManager()

    private let servicePrefix = "com.garageiq.apikey."

    enum APIProvider: String, CaseIterable {
        case marketcheck = "marketcheck"
        case carmd = "carmd"
        case carmdPartner = "carmd_partner"

        var displayName: String {
            switch self {
            case .marketcheck: return "Marketcheck"
            case .carmd: return "CarMD API Key"
            case .carmdPartner: return "CarMD Partner Token"
            }
        }

        var signupURL: URL? {
            switch self {
            case .marketcheck: return URL(string: "https://www.marketcheck.com/apis")
            case .carmd, .carmdPartner: return URL(string: "https://www.carmd.com/api/")
            }
        }

        var description: String {
            switch self {
            case .marketcheck: return "Real active listings, market comps, days on market. Free tier: ~1,000 calls/month."
            case .carmd: return "Real repair costs and maintenance schedules."
            case .carmdPartner: return "Partner token provided alongside your CarMD API key."
            }
        }
    }

    private init() {}

    // MARK: - Keychain Operations

    func setKey(_ key: String, for provider: APIProvider) {
        let account = servicePrefix + provider.rawValue
        let data = Data(key.utf8)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: servicePrefix
        ]

        SecItemDelete(query as CFDictionary)

        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: servicePrefix,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        SecItemAdd(attributes as CFDictionary, nil)
    }

    func getKey(for provider: APIProvider) -> String? {
        let account = servicePrefix + provider.rawValue

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: servicePrefix,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    func removeKey(for provider: APIProvider) {
        let account = servicePrefix + provider.rawValue

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: servicePrefix
        ]

        SecItemDelete(query as CFDictionary)
    }

    func hasKey(for provider: APIProvider) -> Bool {
        return getKey(for: provider) != nil
    }

    var hasMarketcheck: Bool { hasKey(for: .marketcheck) }
    var hasCarMD: Bool { hasKey(for: .carmd) && hasKey(for: .carmdPartner) }
}
