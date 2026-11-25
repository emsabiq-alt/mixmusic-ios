import Foundation

class LyricsService {
    static let shared = LyricsService()
    private let session = URLSession.shared
    
    // Fetch synced lyrics from LRCLIB
    func fetchLyrics(title: String, artist: String) async -> [LyricLine] {
        guard let encodedTitle = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let encodedArtist = artist.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://lrclib.net/api/get?track_name=\(encodedTitle)&artist_name=\(encodedArtist)") else {
            return []
        }
        
        do {
            var request = URLRequest(url: url)
            request.setValue("EmsaMusic iOS App (https://github.com/emsabiq-alt/mixmusic-ios)", forHTTPHeaderField: "User-Agent")
            
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return []
            }
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let syncedLyrics = json["syncedLyrics"] as? String else {
                if let plain = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["plainLyrics"] as? String {
                    return plain.components(separatedBy: "\n").map { LyricLine(time: 0, text: $0) }
                }
                return []
            }
            
            return parseLRC(syncedLyrics)
        } catch {
            print("[LyricsService] Error: \(error)")
            return []
        }
    }
    
    private func parseLRC(_ lrc: String) -> [LyricLine] {
        var lines: [LyricLine] = []
        let rawLines = lrc.components(separatedBy: "\n")
        
        for raw in rawLines {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasPrefix("[") else { continue }
            
            if let closingIndex = trimmed.firstIndex(of: "]") {
                let timeStr = String(trimmed[trimmed.index(after: trimmed.startIndex)..<closingIndex])
                let text = String(trimmed[trimmed.index(after: closingIndex)...]).trimmingCharacters(in: .whitespaces)
                
                if let timeSeconds = parseTimestamp(timeStr), !text.isEmpty {
                    lines.append(LyricLine(time: timeSeconds, text: text))
                }
            }
        }
        
        return lines.sorted { $0.time < $1.time }
    }
    
    private func parseTimestamp(_ str: String) -> TimeInterval? {
        let parts = str.components(separatedBy: ":")
        guard parts.count == 2,
              let minutes = Double(parts[0]),
              let seconds = Double(parts[1]) else { return nil }
        return (minutes * 60.0) + seconds
    }
}
