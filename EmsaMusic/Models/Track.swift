import Foundation

struct Track: Identifiable, Codable, Equatable, Hashable {
    let id: String // YouTube Video ID
    let title: String
    let artist: String
    let thumbnailUrl: String
    let durationSeconds: Int?
    var isKaraokeMode: Bool? = false
    
    var durationFormatted: String {
        guard let sec = durationSeconds, sec > 0 else { return "--:--" }
        let m = sec / 60
        let s = sec % 60
        return String(format: "%d:%02d", m, s)
    }
}

struct LyricLine: Identifiable, Equatable {
    let id = UUID()
    let time: TimeInterval
    let text: String
}

struct Playlist: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var description: String
    var tracks: [Track]
    var createdAt: Date = Date()
    
    var trackCount: Int {
        tracks.count
    }
    
    var coverUrl: String? {
        tracks.first?.thumbnailUrl
    }
}

enum RepeatMode: String, CaseIterable, Codable {
    case off = "Off"
    case all = "All"
    case one = "One"
    
    var iconName: String {
        switch self {
        case .off: return "repeat"
        case .all: return "repeat"
        case .one: return "repeat.1"
        }
    }
}

enum SleepTimerOption: String, CaseIterable, Identifiable {
    case off = "Mati"
    case min15 = "15 Menit"
    case min30 = "30 Menit"
    case min45 = "45 Menit"
    case min60 = "60 Menit"
    case endOfTrack = "Akhir Lagu Ini"
    
    var id: String { rawValue }
    
    var seconds: TimeInterval? {
        switch self {
        case .off: return nil
        case .min15: return 15 * 60
        case .min30: return 30 * 60
        case .min45: return 45 * 60
        case .min60: return 60 * 60
        case .endOfTrack: return -1
        }
    }
}

enum EqualizerPreset: String, CaseIterable, Identifiable, Codable {
    case flat = "Standar (Flat)"
    case bassBoost = "Bass Boost 🔥"
    case vocalClear = "Vocal Clear 🎙️"
    case acoustic = "Akustik / Santai 🎸"
    case pop = "Pop Energik ✨"
    case rock = "Rock & Electronic ⚡"
    
    var id: String { rawValue }
    
    var eqDescription: String {
        switch self {
        case .flat: return "Karakter suara seimbang tanpa modifikasi"
        case .bassBoost: return "Meningkatkan dentuman bass rendah (60Hz - 250Hz)"
        case .vocalClear: return "Memperjelas vokal penyanyi di frekuensi tengah"
        case .acoustic: return "Petikan dawai dan instrumen akustik lebih renyah"
        case .pop: return "Vokal dan beat seimbang untuk lagu pop"
        case .rock: return "Meningkatkan treble dan bass bertenaga tinggi"
        }
    }
    
    // Web Audio Biquad values
    var bassGain: Float {
        switch self {
        case .bassBoost: return 9.0
        case .rock: return 6.0
        case .pop: return 3.0
        case .flat, .vocalClear, .acoustic: return 0.0
        }
    }
    
    var midGain: Float {
        switch self {
        case .vocalClear: return 6.0
        case .acoustic: return 4.0
        case .flat, .bassBoost, .pop, .rock: return 0.0
        }
    }
    
    var trebleGain: Float {
        switch self {
        case .rock: return 6.0
        case .pop: return 4.0
        case .acoustic: return 3.0
        case .flat, .bassBoost, .vocalClear: return 0.0
        }
    }
}
