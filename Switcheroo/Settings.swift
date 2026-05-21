import Foundation

enum Settings {
    private static let postSaveCommandKey = "postSaveCommand"

    static var postSaveCommand: String? {
        get {
            let value = UserDefaults.standard.string(forKey: postSaveCommandKey) ?? ""
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        set {
            let trimmed = (newValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                UserDefaults.standard.removeObject(forKey: postSaveCommandKey)
            } else {
                UserDefaults.standard.set(trimmed, forKey: postSaveCommandKey)
            }
        }
    }
}
