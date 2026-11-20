import Foundation

/// Temporarily disables Mission Control trackpad swipes (3- and 4-finger) via preference
/// keys, then restores the previous values. Undocumented; may change across macOS versions.
final class MissionControlGestureOverride {
    private(set) var isActive = false {
        didSet { onChange?() }
    }

    var onChange: (() -> Void)?

    private var snapshot: Snapshot?
    private static let snapshotDefaultsKey = "MissionControlGestureSnapshot"

    private struct Snapshot: Codable {
        var multitouchThree: Int?
        var multitouchFour: Int?
        var bluetoothThree: Int?
        var bluetoothFour: Int?
        var hostThree: Int?
        var hostFour: Int?
        var missionControlEnabled: Bool?
        var appExposeEnabled: Bool?
    }

    init() {
        // If a previous run crashed mid-override, put the user's gestures back.
        if let data = UserDefaults.standard.data(forKey: Self.snapshotDefaultsKey),
           let saved = try? JSONDecoder().decode(Snapshot.self, from: data) {
            apply(saved)
            clearPersistedSnapshot()
            Self.reloadSettings()
        }
    }

    func setEnabled(_ enabled: Bool) {
        if enabled {
            guard !isActive else { return }
            let snap = capture()
            snapshot = snap
            persist(snap)
            applyDisabled()
            Self.reloadSettings()
            isActive = true
        } else {
            guard isActive, let snap = snapshot else {
                if isActive {
                    isActive = false
                }
                return
            }
            apply(snap)
            snapshot = nil
            clearPersistedSnapshot()
            Self.reloadSettings()
            isActive = false
        }
    }

    func release() {
        setEnabled(false)
    }

    // MARK: - Capture / apply

    private func capture() -> Snapshot {
        Snapshot(
            multitouchThree: intValue(domain: Self.multitouch, key: Self.threeKey),
            multitouchFour: intValue(domain: Self.multitouch, key: Self.fourKey),
            bluetoothThree: intValue(domain: Self.bluetooth, key: Self.threeKey),
            bluetoothFour: intValue(domain: Self.bluetooth, key: Self.fourKey),
            hostThree: hostIntValue(Self.hostThreeKey),
            hostFour: hostIntValue(Self.hostFourKey),
            missionControlEnabled: boolValue(domain: Self.dock, key: Self.missionControlKey),
            appExposeEnabled: boolValue(domain: Self.dock, key: Self.appExposeKey)
        )
    }

    private func applyDisabled() {
        setInt(domain: Self.multitouch, key: Self.threeKey, value: 0)
        setInt(domain: Self.multitouch, key: Self.fourKey, value: 0)
        setInt(domain: Self.bluetooth, key: Self.threeKey, value: 0)
        setInt(domain: Self.bluetooth, key: Self.fourKey, value: 0)
        setHostInt(Self.hostThreeKey, value: 0)
        setHostInt(Self.hostFourKey, value: 0)
        setBool(domain: Self.dock, key: Self.missionControlKey, value: false)
        // Vertical swipes also drive App Exposé; keep Dock prefs consistent while overridden.
        setBool(domain: Self.dock, key: Self.appExposeKey, value: false)
    }

    private func apply(_ snap: Snapshot) {
        if let v = snap.multitouchThree { setInt(domain: Self.multitouch, key: Self.threeKey, value: v) }
        if let v = snap.multitouchFour { setInt(domain: Self.multitouch, key: Self.fourKey, value: v) }
        if let v = snap.bluetoothThree { setInt(domain: Self.bluetooth, key: Self.threeKey, value: v) }
        if let v = snap.bluetoothFour { setInt(domain: Self.bluetooth, key: Self.fourKey, value: v) }
        if let v = snap.hostThree { setHostInt(Self.hostThreeKey, value: v) }
        if let v = snap.hostFour { setHostInt(Self.hostFourKey, value: v) }
        if let v = snap.missionControlEnabled { setBool(domain: Self.dock, key: Self.missionControlKey, value: v) }
        if let v = snap.appExposeEnabled { setBool(domain: Self.dock, key: Self.appExposeKey, value: v) }
    }

    private func persist(_ snap: Snapshot) {
        if let data = try? JSONEncoder().encode(snap) {
            UserDefaults.standard.set(data, forKey: Self.snapshotDefaultsKey)
        }
    }

    private func clearPersistedSnapshot() {
        UserDefaults.standard.removeObject(forKey: Self.snapshotDefaultsKey)
    }

    private static func reloadSettings() {
        let activate = Process()
        activate.executableURL = URL(
            fileURLWithPath: "/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings"
        )
        activate.arguments = ["-u"]
        activate.standardOutput = FileHandle.nullDevice
        activate.standardError = FileHandle.nullDevice
        try? activate.run()
        activate.waitUntilExit()

        // Dock reads showMissionControlGestureEnabled; restart applies it.
        let dock = Process()
        dock.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        dock.arguments = ["Dock"]
        dock.standardOutput = FileHandle.nullDevice
        dock.standardError = FileHandle.nullDevice
        try? dock.run()
        dock.waitUntilExit()
    }

    // MARK: - Preference helpers

    private static let multitouch = "com.apple.AppleMultitouchTrackpad"
    private static let bluetooth = "com.apple.driver.AppleBluetoothMultitouch.trackpad"
    private static let dock = "com.apple.dock"
    private static let threeKey = "TrackpadThreeFingerVertSwipeGesture"
    private static let fourKey = "TrackpadFourFingerVertSwipeGesture"
    private static let hostThreeKey = "com.apple.trackpad.threeFingerVertSwipeGesture"
    private static let hostFourKey = "com.apple.trackpad.fourFingerVertSwipeGesture"
    private static let missionControlKey = "showMissionControlGestureEnabled"
    private static let appExposeKey = "showAppExposeGestureEnabled"

    private func intValue(domain: String, key: String) -> Int? {
        guard let raw = CFPreferencesCopyAppValue(key as CFString, domain as CFString) else {
            return nil
        }
        return (raw as? NSNumber)?.intValue
    }

    private func boolValue(domain: String, key: String) -> Bool? {
        guard let raw = CFPreferencesCopyAppValue(key as CFString, domain as CFString) else {
            return nil
        }
        return (raw as? NSNumber)?.boolValue
    }

    private func hostIntValue(_ key: String) -> Int? {
        guard let raw = CFPreferencesCopyValue(
            key as CFString,
            kCFPreferencesAnyApplication,
            kCFPreferencesCurrentUser,
            kCFPreferencesCurrentHost
        ) else {
            return nil
        }
        return (raw as? NSNumber)?.intValue
    }

    private func setInt(domain: String, key: String, value: Int) {
        CFPreferencesSetAppValue(key as CFString, NSNumber(value: value), domain as CFString)
        CFPreferencesAppSynchronize(domain as CFString)
    }

    private func setBool(domain: String, key: String, value: Bool) {
        CFPreferencesSetAppValue(key as CFString, NSNumber(value: value), domain as CFString)
        CFPreferencesAppSynchronize(domain as CFString)
    }

    private func setHostInt(_ key: String, value: Int) {
        CFPreferencesSetValue(
            key as CFString,
            NSNumber(value: value),
            kCFPreferencesAnyApplication,
            kCFPreferencesCurrentUser,
            kCFPreferencesCurrentHost
        )
        CFPreferencesSynchronize(
            kCFPreferencesAnyApplication,
            kCFPreferencesCurrentUser,
            kCFPreferencesCurrentHost
        )
    }
}
