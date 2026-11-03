import AppKit

final class StatusItemController: NSObject {
    private let statusItem: NSStatusItem
    private let power = PowerAssertionManager()
    private let awakeTimer = AwakeSessionTimer()
    private var countdownTimer: Timer?

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "eye.half.closed",
                accessibilityDescription: "Awake"
            )
            button.image?.isTemplate = true
        }

        power.onChange = { [weak self] in
            guard let self else { return }
            if !self.power.isOverriding {
                self.awakeTimer.stop()
            }
            self.updateIcon()
            self.rebuildMenu()
        }

        awakeTimer.onChange = { [weak self] in
            self?.updateCountdownTimer()
            self?.rebuildMenu()
        }

        awakeTimer.onExpire = { [weak self] in
            self?.power.releaseAll()
        }

        rebuildMenu()
    }

    deinit {
        countdownTimer?.invalidate()
        awakeTimer.stop()
        power.releaseAll()
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    private func updateCountdownTimer() {
        if awakeTimer.isTimed, countdownTimer == nil {
            countdownTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
                self?.rebuildMenu()
            }
        } else if !awakeTimer.isTimed {
            countdownTimer?.invalidate()
            countdownTimer = nil
        }
    }

    private func updateIcon() {
        let name = power.isOverriding ? "eye" : "eye.half.closed"
        statusItem.button?.image = NSImage(
            systemSymbolName: name,
            accessibilityDescription: power.isOverriding ? "Awake active" : "Awake"
        )
        statusItem.button?.image?.isTemplate = true
    }

    private func keepAwakeState() -> NSControl.StateValue {
        switch (power.systemAwake, power.displayAwake) {
        case (true, true): return .on
        case (false, false): return .off
        default: return .mixed
        }
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false

        let keepAwakeItem = NSMenuItem(
            title: "Keep Awake",
            action: #selector(toggleKeepAwake),
            keyEquivalent: ""
        )
        keepAwakeItem.target = self
        keepAwakeItem.state = keepAwakeState()
        menu.addItem(keepAwakeItem)

        let systemItem = NSMenuItem(
            title: "System Awake",
            action: #selector(toggleSystemAwake),
            keyEquivalent: ""
        )
        systemItem.target = self
        systemItem.state = power.systemAwake ? .on : .off
        systemItem.indentationLevel = 1
        menu.addItem(systemItem)

        let displayItem = NSMenuItem(
            title: "Display Awake",
            action: #selector(toggleDisplayAwake),
            keyEquivalent: ""
        )
        displayItem.target = self
        displayItem.state = power.displayAwake ? .on : .off
        displayItem.indentationLevel = 1
        menu.addItem(displayItem)

        var durationTitle = "Turn Off After"
        if let remaining = awakeTimer.remainingDescription {
            durationTitle = "Turn Off After (\(remaining))"
        }
        let durationItem = NSMenuItem(title: durationTitle, action: nil, keyEquivalent: "")
        durationItem.indentationLevel = 1
        durationItem.submenu = durationSubmenu()
        menu.addItem(durationItem)

        menu.addItem(.separator())

        menu.addItem(immediateItem(title: "Lock Screen", action: #selector(lockScreen)))
        menu.addItem(immediateItem(title: "Sleep Display", action: #selector(sleepDisplay)))
        menu.addItem(immediateItem(title: "Sleep Mac", action: #selector(sleepMac)))

        menu.addItem(.separator())

        let launchItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launchItem.target = self
        launchItem.state = LaunchAtLogin.isEnabled ? .on : .off
        menu.addItem(launchItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit Awake",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func durationSubmenu() -> NSMenu {
        let submenu = NSMenu()
        for (index, preset) in AwakeDuration.presets.enumerated() {
            let item = NSMenuItem(
                title: preset.title,
                action: #selector(selectDuration(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.tag = index
            item.state = (awakeTimer.preferredSeconds == preset.seconds) ? .on : .off
            submenu.addItem(item)
        }
        return submenu
    }

    private func immediateItem(title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    // MARK: - Actions

    @objc private func toggleKeepAwake() {
        if power.allAwake {
            power.releaseAll()
        } else {
            power.setAllAwake(true)
            awakeTimer.startPreferred()
        }
    }

    @objc private func toggleSystemAwake() {
        let enabling = !power.systemAwake
        power.setSystemAwake(enabling)
        if enabling {
            awakeTimer.startPreferred()
        }
    }

    @objc private func toggleDisplayAwake() {
        let enabling = !power.displayAwake
        power.setDisplayAwake(enabling)
        if enabling {
            awakeTimer.startPreferred()
        }
    }

    @objc private func selectDuration(_ sender: NSMenuItem) {
        guard AwakeDuration.presets.indices.contains(sender.tag) else { return }
        let preset = AwakeDuration.presets[sender.tag]

        if power.isOverriding {
            awakeTimer.start(seconds: preset.seconds)
        } else {
            power.setAllAwake(true)
            awakeTimer.start(seconds: preset.seconds)
        }
    }

    @objc private func lockScreen() {
        SystemActions.lockScreen()
    }

    @objc private func sleepDisplay() {
        SystemActions.sleepDisplay()
    }

    @objc private func sleepMac() {
        awakeTimer.stop()
        power.releaseAll()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            SystemActions.sleepMac()
        }
    }

    @objc private func toggleLaunchAtLogin() {
        LaunchAtLogin.setEnabled(!LaunchAtLogin.isEnabled)
        rebuildMenu()
    }

    @objc private func quit() {
        countdownTimer?.invalidate()
        awakeTimer.stop()
        power.releaseAll()
        NSApp.terminate(nil)
    }
}
