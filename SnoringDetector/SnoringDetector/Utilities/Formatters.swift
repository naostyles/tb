import Foundation

/// Centralized time-interval string formatters used across views.
enum TimeFormat {
    /// "HH:MM:SS" — wall-clock style, used for the live elapsed timer.
    static func clock(_ s: TimeInterval) -> String {
        String(format: "%02d:%02d:%02d", Int(s) / 3600, (Int(s) % 3600) / 60, Int(s) % 60)
    }

    /// "M:SS" — used for audio playback progress.
    static func playback(_ s: TimeInterval) -> String {
        String(format: "%d:%02d", Int(s) / 60, Int(s) % 60)
    }

    /// "S秒" or "M分S秒" — short duration without leading hours.
    static func shortDuration(_ s: TimeInterval) -> String {
        let m = Int(s) / 60, sec = Int(s) % 60
        return m > 0 ? "\(m)分\(sec)秒" : "\(sec)秒"
    }

    /// "M:SS 経過" or "H:MM:SS 経過" — offset since session start.
    static func elapsed(_ s: TimeInterval) -> String {
        let h = Int(s) / 3600, m = (Int(s) % 3600) / 60, sec = Int(s) % 60
        return h > 0 ? String(format: "%d:%02d:%02d 経過", h, m, sec)
                     : String(format: "%d:%02d 経過", m, sec)
    }

    /// "H時間MM分" — long duration with leading hours, used for total sleep time.
    static func longDuration(_ s: TimeInterval) -> String {
        String(format: "%d時間%02d分", Int(s) / 3600, (Int(s) % 3600) / 60)
    }
}

/// Reusable Japanese-locale DateFormatters. Kept as static lets so they're
/// created once instead of per call.
enum AppDateFormatter {
    private static let jaJP = Locale(identifier: "ja_JP")

    /// "M月d日(E) HH:mm"
    static let sessionDateTime: DateFormatter = make(format: "M月d日(E) HH:mm")

    /// "M月d日(E)"
    static let sessionDate: DateFormatter = make(format: "M月d日(E)")

    /// "HH:mm 就寝"
    static let bedtime: DateFormatter = make(format: "HH:mm 就寝")

    /// Locale-appropriate short time (e.g. "23:00").
    static let shortTime: DateFormatter = {
        let f = DateFormatter()
        f.locale = jaJP
        f.timeStyle = .short
        return f
    }()

    private static func make(format: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = jaJP
        f.dateFormat = format
        return f
    }
}
