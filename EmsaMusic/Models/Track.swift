import Foundation

struct Track: Identifiable, Codable, Equatable, Hashable {
    let id: String // YouTube Video ID
    let title: String
    let artist: String
    let thumbnailUrl: String
    let durationSeconds: Int?
    
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
        case .endOfTrack: return -1 // Flag for track end
        }
    }
}
