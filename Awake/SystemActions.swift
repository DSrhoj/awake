import AppKit
import Foundation

enum SystemActions {
    static func lockScreen() {
        let path = "/System/Library/PrivateFrameworks/login.framework/Versions/Current/login"
        guard let handle = dlopen(path, RTLD_LAZY) else {
            lockScreenFallback()
            return
        }
        defer { dlclose(handle) }

        typealias LockFn = @convention(c) () -> Void
        guard let symbol = dlsym(handle, "SACLockScreenImmediate") else {
            lockScreenFallback()
            return
        }
        unsafeBitCast(symbol, to: LockFn.self)()
    }

    static func sleepDisplay() {
        run("/usr/bin/pmset", arguments: ["displaysleepnow"])
    }

    static func sleepMac() {
        run("/usr/bin/pmset", arguments: ["sleepnow"])
    }

    private static func lockScreenFallback() {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x0C, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x0C, keyDown: false)
        keyDown?.flags = [.maskCommand, .maskControl]
        keyUp?.flags = [.maskCommand, .maskControl]
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }

    private static func run(_ launchPath: String, arguments: [String]) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
    }
}
