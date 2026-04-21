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
    let id: UUID; let exercise: OralExercise; let sets: Int; let completedAt: Date
    init(id: UUID = UUID(), exercise: OralExercise, sets: Int = 1, completedAt: Date = Date()) {
        self.id = id; self.exercise = exercise; self.sets = sets; self.completedAt = completedAt
    }
}

// MARK: - Lifestyle Log

struct LifestyleLog: Identifiable, Codable {
    let id: UUID
    var date: Date           // start of day (Calendar.startOfDay)
    var alcoholUnits: Double // 0–5+ standard drinks
    var exerciseMinutes: Int // aerobic exercise
    var fatigueLevel: Int    // 1–5
    var weight: Double?      // kg
    var countermeasures: [Countermeasure]
    var exercises: [ExerciseEntry]
    var notes: String

    init(id: UUID = UUID(), date: Date = Date()) {
        self.id = id
        self.date = Calendar.current.startOfDay(for: date)
        self.alcoholUnits = 0; self.exerciseMinutes = 0
        self.fatigueLevel = 3; self.weight = nil
        self.countermeasures = []; self.exercises = []; self.notes = ""
    }
}
