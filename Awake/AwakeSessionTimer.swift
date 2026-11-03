import Foundation

struct AwakeDuration {
    let title: String
    /// `nil` means until manually turned off.
    let seconds: TimeInterval?

    static let presets: [AwakeDuration] = [
        AwakeDuration(title: "Until Turned Off", seconds: nil),
        AwakeDuration(title: "15 Minutes", seconds: 15 * 60),
        AwakeDuration(title: "30 Minutes", seconds: 30 * 60),
        AwakeDuration(title: "1 Hour", seconds: 60 * 60),
        AwakeDuration(title: "3 Hours", seconds: 3 * 60 * 60),
    ]
}

final class AwakeSessionTimer {
    private var workItem: DispatchWorkItem?
    private(set) var endDate: Date?

    /// Last chosen duration (`nil` = until turned off). Survives cancel.
    private(set) var preferredSeconds: TimeInterval?

    var onChange: (() -> Void)?
    var onExpire: (() -> Void)?

    var isTimed: Bool { endDate != nil }

    var remainingDescription: String? {
        guard let endDate else { return nil }
        let remaining = max(0, endDate.timeIntervalSinceNow)
        if remaining < 60 {
            return "\(Int(remaining.rounded()))s left"
        }
        let minutes = Int((remaining / 60).rounded(.up))
        if minutes < 60 {
            return "\(minutes)m left"
        }
        let hours = minutes / 60
        let mins = minutes % 60
        return mins == 0 ? "\(hours)h left" : "\(hours)h \(mins)m left"
    }

    func selectPreferred(_ seconds: TimeInterval?) {
        preferredSeconds = seconds
    }

    /// Starts or refreshes the auto-off timer using `preferredSeconds`.
    func startPreferred() {
        start(seconds: preferredSeconds)
    }

    func start(seconds: TimeInterval?) {
        preferredSeconds = seconds
        clearActiveTimer()

        guard let seconds else {
            onChange?()
            return
        }

        let item = DispatchWorkItem { [weak self] in
            self?.clearActiveTimer()
            self?.onExpire?()
            self?.onChange?()
        }

        workItem = item
        endDate = Date().addingTimeInterval(seconds)
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: item)
        onChange?()
    }

    /// Stops a running countdown without forgetting the preferred duration.
    func stop() {
        clearActiveTimer()
        onChange?()
    }

    private func clearActiveTimer() {
        workItem?.cancel()
        workItem = nil
        endDate = nil
    }
}
