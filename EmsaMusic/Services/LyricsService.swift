import Foundation

class LyricsService {
    static let shared = LyricsService()
    private let session = URLSession.shared
    
    // Clean noisy titles from YouTube (e.g. "(Official Music Video)", "[Audio]", "feat. ...")
    func cleanTitle(_ title: String) -> String {
        var clean = title
        let patterns = [
            #"\s*[\(\[].*?(official|video|audio|lirik|lyrics|remix|clip|ft\.|feat\.|hd|4k).*?[\)\]]"#,
            #"\s*-\s*(official|video|audio|lirik|lyrics).*$"#,
            #"\s*\|\s*.*$"#
        ]
        for p in patterns {
            clean = clean.replacingOccurrences(of: p, with: "", options: [.regularExpression, .caseInsensitive])
        }
        return clean.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // Clean artist names (strip " - Topic", "VEVO", etc.)
    func cleanArtist(_ artist: String) -> String {
        var clean = artist
        let patterns = [
            #"\s*-\s*Topic"#,
            #"\s*VEVO"#,
            #"\s*Official"#,
            #"\s*,.*$"#
        ]
        for p in patterns {
            clean = clean.replacingOccurrences(of: p, with: "", options: [.regularExpression, .caseInsensitive])
        }
        return clean.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // Fetch synced lyrics from LRCLIB with multi-tier search
    func fetchLyrics(title: String, artist: String, duration: TimeInterval? = nil) async -> [LyricLine] {
        let cleanedTitle = cleanTitle(title)
        let cleanedArtist = cleanArtist(artist)
        
        // 1. Exact get API
        if let lines = await fetchFromGetEndpoint(title: cleanedTitle, artist: cleanedArtist, duration: duration), !lines.isEmpty {
            return lines
        }
        
        // 2. Search fallback API (fuzzy matching)
        if let lines = await fetchFromSearchEndpoint(title: cleanedTitle, artist: cleanedArtist), !lines.isEmpty {
            return lines
        }
        
        // 3. Fallback with original raw title
        if cleanedTitle != title {
            if let lines = await fetchFromGetEndpoint(title: title, artist: artist, duration: duration), !lines.isEmpty {
                return lines
            }
        }
        
        return []
    }
    
    private func fetchFromGetEndpoint(title: String, artist: String, duration: TimeInterval?) async -> [LyricLine]? {
        guard let encodedTitle = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let encodedArtist = artist.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        
        var urlStr = "https://lrclib.net/api/get?track_name=\(encodedTitle)&artist_name=\(encodedArtist)"
        if let d = duration, d > 0 {
            urlStr += "&duration=\(Int(d))"
        }
        
        guard let url = URL(string: urlStr) else { return nil }
        
        do {
            var request = URLRequest(url: url)
            request.setValue("EmsaMusic iOS App (https://github.com/emsabiq-alt/mixmusic-ios)", forHTTPHeaderField: "User-Agent")
            request.timeoutInterval = 7
            
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return nil
            }
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
            if let synced = json["syncedLyrics"] as? String, !synced.isEmpty {
                return parseLRC(synced)
            } else if let plain = json["plainLyrics"] as? String, !plain.isEmpty {
                return plain.components(separatedBy: "\n").map { LyricLine(time: 0, text: $0) }
            }
        } catch {
            return nil
        }
        return nil
    }
    
    private func fetchFromSearchEndpoint(title: String, artist: String) async -> [LyricLine]? {
        guard let encodedQuery = "\(title) \(artist)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://lrclib.net/api/search?q=\(encodedQuery)") else {
            return nil
        }
        
        do {
            var request = URLRequest(url: url)
            request.setValue("EmsaMusic iOS App", forHTTPHeaderField: "User-Agent")
            request.timeoutInterval = 7
            
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                  let list = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                return nil
            }
            
            for item in list {
                if let synced = item["syncedLyrics"] as? String, !synced.isEmpty {
                    return parseLRC(synced)
                }
            }
        } catch {
            return nil
        }
        return nil
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
