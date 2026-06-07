import Foundation

struct MouseDeviceStore {
    private let userDefaults: UserDefaults
    private let deviceSettingsKey = "MouseDeviceSettings"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func load() -> [String: MouseDevice]? {
        guard let data = userDefaults.data(forKey: deviceSettingsKey),
              let savedSettings = try? JSONDecoder().decode([String: MouseDevice].self, from: data) else {
            return nil
        }

        return savedSettings
    }

    func save(_ deviceSettings: [String: MouseDevice]) {
        guard let data = try? JSONEncoder().encode(deviceSettings) else {
            print("Failed to encode device settings")
            return
        }

        userDefaults.set(data, forKey: deviceSettingsKey)
    }
}
