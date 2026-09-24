import Foundation

public enum UpdateSchedule {
    public static let interval: TimeInterval = 24 * 60 * 60

    /// Due a day after the last check. A last check in the future means the clock was set back, so it doesn't count.
    public static func isDue(lastCheck: Date?, now: Date, interval: TimeInterval = interval) -> Bool {
        guard let lastCheck else { return true }
        let elapsed = now.timeIntervalSince(lastCheck)
        return elapsed < 0 || elapsed >= interval
    }
}
