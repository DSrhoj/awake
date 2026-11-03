import Foundation
import IOKit.pwr_mgt

final class PowerAssertionManager {
    private(set) var systemAwake = false {
        didSet { onChange?() }
    }

    private(set) var displayAwake = false {
        didSet { onChange?() }
    }

    var isOverriding: Bool { systemAwake || displayAwake }

    var onChange: (() -> Void)?

    private var systemAssertionID: IOPMAssertionID = 0
    private var displayAssertionID: IOPMAssertionID = 0

    func setSystemAwake(_ enabled: Bool) {
        if enabled == systemAwake { return }
        if enabled {
            let result = IOPMAssertionCreateWithName(
                kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "Awake is preventing system sleep" as CFString,
                &systemAssertionID
            )
            systemAwake = result == kIOReturnSuccess
            if !systemAwake {
                systemAssertionID = 0
            }
        } else {
            if systemAssertionID != 0 {
                IOPMAssertionRelease(systemAssertionID)
                systemAssertionID = 0
            }
            systemAwake = false
        }
    }

    func setDisplayAwake(_ enabled: Bool) {
        if enabled == displayAwake { return }
        if enabled {
            let result = IOPMAssertionCreateWithName(
                kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "Awake is preventing display sleep" as CFString,
                &displayAssertionID
            )
            displayAwake = result == kIOReturnSuccess
            if !displayAwake {
                displayAssertionID = 0
            }
        } else {
            if displayAssertionID != 0 {
                IOPMAssertionRelease(displayAssertionID)
                displayAssertionID = 0
            }
            displayAwake = false
        }
    }

    var allAwake: Bool { systemAwake && displayAwake }

    func setAllAwake(_ enabled: Bool) {
        let previous = onChange
        onChange = nil
        setSystemAwake(enabled)
        setDisplayAwake(enabled)
        onChange = previous
        onChange?()
    }

    func releaseAll() {
        setAllAwake(false)
    }
}
