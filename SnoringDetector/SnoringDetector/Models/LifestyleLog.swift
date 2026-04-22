import Foundation

// MARK: - Countermeasure

enum Countermeasure: String, Codable, CaseIterable, Identifiable {
    var id: String { rawValue }
    case lateralPillow = "横向き枕"
    case nasalStrip    = "鼻腔拡張テープ"
    case mouthpiece    = "マウスピース"
    case nasalDilator  = "鼻腔拡張器"
    case elevatedHead  = "頭を高くする"
    case noAlcohol     = "断酒"
    case humidifier    = "加湿器使用"

    var icon: String {
        switch self {
        case .lateralPillow: "bed.double.fill"
        case .nasalStrip:    "bandage.fill"
        case .mouthpiece:    "mouth.fill"
        case .nasalDilator:  "wind"
        case .elevatedHead:  "arrow.up.circle.fill"
        case .noAlcohol:     "xmark.circle.fill"
        case .humidifier:    "drop.fill"
        }
    }
}

// MARK: - Oral / Facial Exercise

enum OralExercise: String, Codable, CaseIterable, Identifiable {
    var id: String { rawValue }
    case tongue    = "舌トレーニング"
    case throat    = "喉のトレーニング"
    case jaw       = "顎の運動"
    case breathing = "腹式呼吸"
    case singing   = "ハミング・歌"

    var instruction: String {
        switch self {
        case .tongue:    "舌を上顎に押しつけ10秒キープ×10回"
        case .throat:    "口を大きく開けて「あー」と5秒発声×10回"
        case .jaw:       "下顎を前後左右にゆっくり動かす×10回"
        case .breathing: "腹式呼吸を5分間ゆっくり繰り返す"
        case .singing:   "好きな曲をハミング or 歌う（5分以上）"
        }
    }

    var icon: String {
        switch self {
        case .tongue:    "mouth.fill"
        case .throat:    "waveform"
        case .jaw:       "face.smiling"
        case .breathing: "wind"
        case .singing:   "music.note"
        }
    }
}

struct ExerciseEntry: Identifiable, Codable {
    var id: UUID = UUID()
    var exercise: OralExercise
    var sets: Int = 1
    var completedAt: Date = Date()
}

// MARK: - Lifestyle Log

struct LifestyleLog: Identifiable, Codable {
    var id: UUID = UUID()
    var date: Date                               // start of day (Calendar.startOfDay)
    var alcoholUnits: Double = 0                 // 0–5+ standard drinks
    var exerciseMinutes: Int = 0                 // aerobic exercise
    var fatigueLevel: Int = 3                    // 1–5
    var weight: Double?                          // kg
    var countermeasures: [Countermeasure] = []
    var exercises: [ExerciseEntry] = []
    var notes: String = ""

    init(date: Date = Date()) {
        self.date = Calendar.current.startOfDay(for: date)
    }
}
