import Foundation

class YouTubeService {
    static let shared = YouTubeService()
    private let session = URLSession.shared
    
    // 1. Search YouTube Music using Innertube API
    func search(query: String) async throws -> [Track] {
        guard let url = URL(string: "https://music.youtube.com/youtubei/v1/search?prettyPrint=false") else {
            return []
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("https://music.youtube.com", forHTTPHeaderField: "Origin")
        request.setValue("https://music.youtube.com", forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        
        let payload: [String: Any] = [
            "context": [
                "client": [
                    "clientName": "WEB_REMIX",
                    "clientVersion": "1.20240501.01.00",
                    "hl": "id",
                    "gl": "ID"
                ]
            ],
            "query": query,
            "params": "Eg-KAQwIABAAGAAgACgAMABqChAEEAMQCRAFEAo%3D" // Filter to Songs & Videos
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return try await fallbackSearch(query: query)
        }
        
        return parseSearchResults(from: data)
    }
    
    // 2. Resolve Audio Stream URL via Innertube Player API
    func resolveStreamURL(videoId: String) async throws -> URL? {
        guard let url = URL(string: "https://www.youtube.com/youtubei/v1/player?prettyPrint=false") else {
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("com.google.ios.youtubemusic/6.41.1 (iPhone14,5; U; CPU iOS 17_5 like Mac OS X)", forHTTPHeaderField: "User-Agent")
        
        let payload: [String: Any] = [
            "context": [
                "client": [
                    "clientName": "IOS_MUSIC",
                    "clientVersion": "6.41.1",
                    "osName": "iOS",
                    "osVersion": "17.5",
                    "deviceModel": "iPhone14,5",
                    "hl": "en",
                    "gl": "US"
                ]
            ],
            "videoId": videoId,
            "playbackContext": [
                "contentPlaybackContext": [
                    "html5Preference": "HTML5_PREF_WANTS"
                ]
            ],
            "contentCheckOk": true,
            "racyCheckOk": true
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return nil
        }
        
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let streamingData = json["streamingData"] as? [String: Any],
           let adaptiveFormats = streamingData["adaptiveFormats"] as? [[String: Any]] {
            
            // Prefer audio/mp4 (AAC) or audio/webm (Opus)
            for format in adaptiveFormats {
                if let mimeType = format["mimeType"] as? String, mimeType.contains("audio"),
                   let urlString = format["url"] as? String,
                   let streamUrl = URL(string: urlString) {
                    return streamUrl
                }
            }
        }
        
        return nil
    }
    
    // Fallback search parser
    private func fallbackSearch(query: String) async throws -> [Track] {
        // Piped / Invidious public instance fallback
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://pipedapi.kavin.rocks/search?q=\(encoded)&filter=music_songs") else {
            return []
        }
        let (data, _) = try await session.data(from: url)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["items"] as? [[String: Any]] else {
            return []
        }
        
        return items.compactMap { item in
            guard let rawUrl = item["url"] as? String,
                  let id = rawUrl.components(separatedBy: "=").last,
                  let title = item["title"] as? String else { return nil }
            let uploader = item["uploaderName"] as? String ?? "Unknown"
            let thumbnail = item["thumbnail"] as? String ?? ""
            let duration = item["duration"] as? Int
            return Track(id: id, title: title, artist: uploader, thumbnailUrl: thumbnail, durationSeconds: duration)
        }
    }
    
    private func parseSearchResults(from data: Data) -> [Track] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }
        var tracks: [Track] = []
        
        // Deep traversal of Innertube JSON structure
        func searchNodes(_ obj: Any) {
            if let dict = obj as? [String: Any] {
                if let renderer = dict["musicResponsiveListItemRenderer"] as? [String: Any] {
                    if let track = extractTrack(from: renderer) {
                        tracks.append(track)
                    }
                }
                for value in dict.values {
                    searchNodes(value)
                }
            } else if let array = obj as? [Any] {
                for item in array {
                    searchNodes(item)
                }
            }
        }
        
        searchNodes(json)
        return tracks
    }
    
    private func extractTrack(from renderer: [String: Any]) -> Track? {
        guard let flexColumns = renderer["flexColumns"] as? [[String: Any]],
              flexColumns.count >= 2 else { return nil }
        
        // Title
        guard let titleCol = flexColumns[0]["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any],
              let titleText = titleCol["text"] as? [String: Any],
              let titleRuns = titleText["runs"] as? [[String: Any]],
              let title = titleRuns.first?["text"] as? String else { return nil }
              
        // Artist
        let artistCol = flexColumns[1]["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any]
        let artistText = artistCol?["text"] as? [String: Any]
        let artistRuns = artistText?["runs"] as? [[String: Any]]
        let artist = artistRuns?.first?["text"] as? String ?? "Various Artists"
        
        // Video ID
        var videoId: String?
        if let navEndpoint = renderer["navigationEndpoint"] as? [String: Any],
           let watchEndpoint = navEndpoint["watchEndpoint"] as? [String: Any] {
            videoId = watchEndpoint["videoId"] as? String
        } else if let overlay = renderer["overlay"] as? [String: Any],
                  let playRenderer = overlay["musicItemThumbnailOverlayRenderer"] as? [String: Any],
                  let content = playRenderer["content"] as? [String: Any],
                  let btn = content["musicPlayButtonRenderer"] as? [String: Any],
                  let ep = btn["playNavigationEndpoint"] as? [String: Any],
                  let wEp = ep["watchEndpoint"] as? [String: Any] {
            videoId = wEp["videoId"] as? String
        }
        
        guard let id = videoId else { return nil }
        
        // Thumbnail
        var thumb = ""
        if let thumbDict = renderer["thumbnail"] as? [String: Any],
           let musicThumb = thumbDict["musicThumbnailRenderer"] as? [String: Any],
           let thumbObj = musicThumb["thumbnail"] as? [String: Any],
           let thumbs = thumbObj["thumbnails"] as? [[String: Any]],
           let lastThumb = thumbs.last?["url"] as? String {
            thumb = lastThumb
        }
        
        return Track(id: id, title: title, artist: artist, thumbnailUrl: thumb, durationSeconds: nil)
    }
}
