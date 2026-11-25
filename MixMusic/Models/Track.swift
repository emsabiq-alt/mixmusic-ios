import Foundation

struct Track: Identifiable, Codable, Equatable {
    let id: String // YouTube Video ID
    let title: String
    let artist: String
    let thumbnailUrl: String
    let durationSeconds: Int?
    
    var durationFormatted: String {
        guard let sec = durationSeconds else { return "--:--" }
        let m = sec / 60
        let s = sec % 60
        return String(format: "%d:%02d", m, s)
    }
}

struct LyricLine: Identifiable, Equatable {
    let id = UUID()
    let time: TimeInterval // in seconds
    let text: String
}
