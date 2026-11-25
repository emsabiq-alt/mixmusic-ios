import Foundation

class YouTubeMusicService {
    static let shared = YouTubeMusicService()
    private let session = URLSession.shared
    
    // 1. Trending Songs for Home
    func fetchTrending() async -> [Track] {
        let queries = ["Top Hits Indonesia", "Lagu Populer Indonesia", "Viral Hits Indonesia", "Global Top 50"]
        for q in queries {
            if let tracks = try? await search(query: q), !tracks.isEmpty {
                return tracks
            }
        }
        return []
    }
    
    // Official Top 50 Indonesia Chart
    func fetchTop50Indonesia() async -> [Track] {
        guard let url = URL(string: "https://music.youtube.com/youtubei/v1/browse?prettyPrint=false") else {
            return []
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("https://music.youtube.com/", forHTTPHeaderField: "Referer")
        request.setValue("https://music.youtube.com", forHTTPHeaderField: "Origin")
        request.setValue("67", forHTTPHeaderField: "X-YouTube-Client-Name")
        request.setValue("1.20240501.01.00", forHTTPHeaderField: "X-YouTube-Client-Version")
        request.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        
        let payload: [String: Any] = [
            "context": [
                "client": [
                    "clientName": "WEB_REMIX",
                    "clientVersion": "1.20240501.01.00",
                    "hl": "id",
                    "gl": "ID"
                ]
            ],
            "browseId": "VLPL4fGSI1pDJn5ObxTlEPlkkornHXUiKX1z"
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        
        guard let (data, response) = try? await session.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return await fetchTrending()
        }
        
        let contents = json["contents"] as? [String: Any]
        let twoCol = contents?["twoColumnBrowseResultsRenderer"] as? [String: Any]
        let sec = twoCol?["secondaryContents"] as? [String: Any]
        let secList = sec?["sectionListRenderer"] as? [String: Any]
        let sections = secList?["contents"] as? [[String: Any]] ?? []
        
        var chartTracks: [Track] = []
        for s in sections {
            guard let shelf = s["musicPlaylistShelfRenderer"] as? [String: Any],
                  let items = shelf["contents"] as? [[String: Any]] else { continue }
            
            for item in items {
                guard let r = item["musicResponsiveListItemRenderer"] as? [String: Any],
                      let flexCols = r["flexColumns"] as? [[String: Any]], !flexCols.isEmpty else { continue }
                
                let title = (flexCols[0]["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any])?["text"] as? [String: Any]
                let titleStr = ((title?["runs"] as? [[String: Any]])?.first?["text"] as? String) ?? ""
                
                var artistStr = "Various Artists"
                if flexCols.count > 1 {
                    let artist = (flexCols[1]["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any])?["text"] as? [String: Any]
                    artistStr = ((artist?["runs"] as? [[String: Any]])?.first?["text"] as? String) ?? "Various Artists"
                }
                
                var videoId = (r["playlistItemData"] as? [String: Any])?["videoId"] as? String
                if videoId == nil || videoId?.isEmpty == true {
                    let nav = r["navigationEndpoint"] as? [String: Any]
                    videoId = (nav?["watchEndpoint"] as? [String: Any])?["videoId"] as? String
                }
                
                var thumb = ""
                if let thumbRenderer = (r["thumbnail"] as? [String: Any])?["musicThumbnailRenderer"] as? [String: Any],
                   let thumbs = (thumbRenderer["thumbnail"] as? [String: Any])?["thumbnails"] as? [[String: Any]],
                   let last = thumbs.last?["url"] as? String {
                    thumb = last
                }
                
                if let id = videoId, !id.isEmpty && !titleStr.isEmpty {
                    chartTracks.append(Track(id: id, title: titleStr, artist: artistStr, thumbnailUrl: thumb, durationSeconds: nil))
                }
                
                if chartTracks.count >= 50 { break }
            }
            if chartTracks.count >= 50 { break }
        }
        
        return chartTracks.isEmpty ? await fetchTrending() : chartTracks
    }
    
    // 2. Search YouTube Music using MixMusic FilterSongs specification
    func search(query: String) async throws -> [Track] {
        guard let url = URL(string: "https://music.youtube.com/youtubei/v1/search?prettyPrint=false") else {
            return []
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("https://music.youtube.com/", forHTTPHeaderField: "Referer")
        request.setValue("https://music.youtube.com", forHTTPHeaderField: "Origin")
        request.setValue("67", forHTTPHeaderField: "X-YouTube-Client-Name")
        request.setValue("1.20240501.01.00", forHTTPHeaderField: "X-YouTube-Client-Version")
        request.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        
        // Exact FilterSongs param from desktop MixMusic
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
            "params": "EgWKAQIIAWoKEAkQBRAKEAMQBA%3D%3D"
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return []
        }
        
        return parseMusicSearchResults(data: data)
    }
    
    // 3. Resolve Direct Audio Stream URL with Multi-tier Resilience
    func resolveStreamURL(videoId: String) async throws -> URL? {
        // Tier 1: Try Innertube iOS Music Player API
        if let streamUrl = try? await resolveViaInnertube(videoId: videoId) {
            return streamUrl
        }
        
        // Tier 2: Public Invidious / Piped Mirror fallback
        if let streamUrl = try? await resolveViaPublicMirror(videoId: videoId) {
            return streamUrl
        }
        
        return nil
    }
    
    private func resolveViaInnertube(videoId: String) async throws -> URL? {
        guard let url = URL(string: "https://music.youtube.com/youtubei/v1/player?prettyPrint=false") else {
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("com.google.ios.youtubemusic/6.41.1 (iPhone14,5; U; CPU iOS 17_5 like Mac OS X)", forHTTPHeaderField: "User-Agent")
        request.setValue("67", forHTTPHeaderField: "X-YouTube-Client-Name")
        request.setValue("1.20240501.01.00", forHTTPHeaderField: "X-YouTube-Client-Version")
        request.setValue("https://music.youtube.com/", forHTTPHeaderField: "Referer")
        
        let payload: [String: Any] = [
            "context": [
                "client": [
                    "clientName": "WEB_REMIX",
                    "clientVersion": "1.20240501.01.00",
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
        
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let streamingData = json["streamingData"] as? [String: Any],
           let adaptiveFormats = streamingData["adaptiveFormats"] as? [[String: Any]] {
            
            // Look for audio formats with direct url
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
    
    private func resolveViaPublicMirror(videoId: String) async throws -> URL? {
        let mirrors = [
            "https://pipedapi.kavin.rocks/streams/\(videoId)",
            "https://api.piped.private.coffee/streams/\(videoId)"
        ]
        
        for mirror in mirrors {
            guard let url = URL(string: mirror) else { continue }
            var req = URLRequest(url: url)
            req.timeoutInterval = 6
            if let (data, resp) = try? await session.data(for: req),
               let http = resp as? HTTPURLResponse, http.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let audioStreams = json["audioStreams"] as? [[String: Any]] {
                for audio in audioStreams {
                    if let rawUrl = audio["url"] as? String, let streamUrl = URL(string: rawUrl) {
                        return streamUrl
                    }
                }
            }
        }
        return nil
    }
    
    // Exact Innertube parser from desktop MixMusic
    private func parseMusicSearchResults(data: Data) -> [Track] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }
        var resultTracks: [Track] = []
        
        let contents = json["contents"] as? [String: Any]
        let tabbed = contents?["tabbedSearchResultsRenderer"] as? [String: Any]
        let tabs = tabbed?["tabs"] as? [[String: Any]]
        let firstTab = tabs?.first
        let tabContent = firstTab?["tabRenderer"] as? [String: Any]
        let secList = tabContent?["content"] as? [String: Any]
        let renderer = secList?["sectionListRenderer"] as? [String: Any]
        let sections = renderer?["contents"] as? [[String: Any]] ?? []
        
        for section in sections {
            guard let shelf = section["musicShelfRenderer"] as? [String: Any],
                  let items = shelf["contents"] as? [[String: Any]] else { continue }
            
            for item in items {
                guard let r = item["musicResponsiveListItemRenderer"] as? [String: Any],
                      let flexCols = r["flexColumns"] as? [[String: Any]],
                      !flexCols.isEmpty else { continue }
                
                // 1. Title (from flexColumns[0])
                guard let col0 = flexCols[0]["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any],
                      let text0 = col0["text"] as? [String: Any],
                      let runs0 = text0["runs"] as? [[String: Any]],
                      let title = runs0.first?["text"] as? String, !title.isEmpty else { continue }
                
                // 2. Video ID (playlistItemData or watchEndpoint)
                var videoId: String? = nil
                if let plData = r["playlistItemData"] as? [String: Any] {
                    videoId = plData["videoId"] as? String
                }
                if videoId == nil || videoId?.isEmpty == true {
                    if let nav = r["navigationEndpoint"] as? [String: Any],
                       let watch = nav["watchEndpoint"] as? [String: Any] {
                        videoId = watch["videoId"] as? String
                    }
                }
                if videoId == nil || videoId?.isEmpty == true {
                    if let overlay = r["overlay"] as? [String: Any],
                       let overlayContent = (overlay["musicItemThumbnailOverlayRenderer"] as? [String: Any])?["content"] as? [String: Any],
                       let playBtn = overlayContent["musicPlayButtonRenderer"] as? [String: Any],
                       let nav = playBtn["playNavigationEndpoint"] as? [String: Any],
                       let watch = nav["watchEndpoint"] as? [String: Any] {
                        videoId = watch["videoId"] as? String
                    }
                }
                
                guard let validId = videoId, !validId.isEmpty else { continue }
                
                // 3. Artist & Duration (from flexColumns[1])
                var artistName = "Various Artists"
                var durationSec: Int? = nil
                
                if flexCols.count > 1,
                   let col1 = flexCols[1]["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any],
                   let text1 = col1["text"] as? [String: Any],
                   let runs1 = text1["runs"] as? [[String: Any]] {
                    
                    for run in runs1 {
                        if let t = run["text"] as? String, t != " • ", !t.contains(":") {
                            artistName = t
                            break
                        }
                    }
                    if let lastRun = runs1.last?["text"] as? String, lastRun.contains(":") {
                        let parts = lastRun.components(separatedBy: ":")
                        if parts.count == 2, let m = Int(parts[0]), let s = Int(parts[1]) {
                            durationSec = (m * 60) + s
                        }
                    }
                }
                
                // 4. Thumbnail (largest)
                var thumbUrl = ""
                if let thumbRenderer = (r["thumbnail"] as? [String: Any])?["musicThumbnailRenderer"] as? [String: Any],
                   let thumbObj = thumbRenderer["thumbnail"] as? [String: Any],
                   let thumbs = thumbObj["thumbnails"] as? [[String: Any]],
                   let last = thumbs.last?["url"] as? String {
                    thumbUrl = last
                }
                
                let track = Track(id: validId, title: title, artist: artistName, thumbnailUrl: thumbUrl, durationSeconds: durationSec)
                resultTracks.append(track)
            }
        }
        
        return resultTracks
    }
    
    // Fetch Studio Instrumental / Karaoke Track ID
    func fetchInstrumentalTrack(title: String, artist: String) async -> String? {
        let cleanTitle = LyricsService.shared.cleanTitle(title)
        let cleanArtist = LyricsService.shared.cleanArtist(artist)
        let query = "\(cleanTitle) \(cleanArtist) karaoke"
        
        guard let url = URL(string: "https://music.youtube.com/youtubei/v1/search?prettyPrint=false") else {
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("https://music.youtube.com/", forHTTPHeaderField: "Referer")
        request.setValue("https://music.youtube.com", forHTTPHeaderField: "Origin")
        request.setValue("67", forHTTPHeaderField: "X-YouTube-Client-Name")
        request.setValue("1.20240501.01.00", forHTTPHeaderField: "X-YouTube-Client-Version")
        request.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        
        // Search specifically in Videos category (params: EgWKAQIQAWoKEAkQBRAKEAMQBA%3D%3D) for authentic karaoke
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
            "params": "EgWKAQIQAWoKEAkQBRAKEAMQBA%3D%3D"
        ]
        
        guard let postBody = try? JSONSerialization.data(withJSONObject: payload) else { return nil }
        request.httpBody = postBody
        
        guard let (data, response) = try? await session.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        
        guard let contents = json["contents"] as? [String: Any],
              let tabbed = contents["tabbedSearchResultsRenderer"] as? [String: Any],
              let tabs = tabbed["tabs"] as? [[String: Any]],
              let firstTab = tabs.first?["tabRenderer"] as? [String: Any],
              let content = firstTab["content"] as? [String: Any],
              let sectionList = content["sectionListRenderer"] as? [String: Any],
              let sections = sectionList["contents"] as? [[String: Any]] else {
            return nil
        }
        
        for section in sections {
            if let shelf = section["musicShelfRenderer"] as? [String: Any],
               let items = shelf["contents"] as? [[String: Any]] {
                for it in items {
                    if let r = it["musicResponsiveListItemRenderer"] as? [String: Any] {
                        let flexCols = r["flexColumns"] as? [[String: Any]] ?? []
                        var itemTitle = ""
                        if !flexCols.isEmpty {
                            let titleObj = flexCols[0]["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any]
                            let runs = (titleObj?["text"] as? [String: Any])?["runs"] as? [[String: Any]]
                            itemTitle = runs?.first?["text"] as? String ?? ""
                        }
                        
                        var videoId = (r["playlistItemData"] as? [String: Any])?["videoId"] as? String
                        if videoId == nil || videoId?.isEmpty == true {
                            let nav = r["navigationEndpoint"] as? [String: Any]
                            videoId = (nav?["watchEndpoint"] as? [String: Any])?["videoId"] as? String
                        }
                        
                        let lower = itemTitle.lowercased()
                        if let vid = videoId, !vid.isEmpty {
                            if lower.contains("karaoke") || lower.contains("instrumental") || lower.contains("minus one") || lower.contains("tanpa vokal") {
                                return vid
                            }
                        }
                    }
                }
            }
        }
        
        return nil
    }
    
    // Resolve Direct Native Audio Stream URL (itag 140 AAC-LC stereo)
    private var cachedVisitorData: String?
    private var visitorDataTimestamp: Date?
    private let visionAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 15_7_3) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Safari/605.1.15"
    
    private func fetchVisitorDataIfNeeded() async -> String? {
        if let v = cachedVisitorData, let ts = visitorDataTimestamp, Date().timeIntervalSince(ts) < 14400 {
            return v
        }
        guard let url = URL(string: "https://www.youtube.com/youtubei/v1/visitor_id?prettyPrint=false") else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(visionAgent, forHTTPHeaderField: "User-Agent")
        req.setValue("101", forHTTPHeaderField: "X-YouTube-Client-Name")
        req.setValue("1.02", forHTTPHeaderField: "X-YouTube-Client-Version")
        
        let body: [String: Any] = ["context": ["client": [
            "clientName": "VISIONOS",
            "clientVersion": "1.02",
            "deviceMake": "Apple",
            "deviceModel": "RealityDevice17,1",
            "osName": "visionOS",
            "osVersion": "26.5.23O471",
            "userAgent": visionAgent,
            "hl": "id",
            "gl": "ID"
        ]]]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        guard let (data, resp) = try? await session.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let respCtx = json["responseContext"] as? [String: Any],
              let vis = respCtx["visitorData"] as? String, !vis.isEmpty else {
            return nil
        }
        self.cachedVisitorData = vis
        self.visitorDataTimestamp = Date()
        return vis
    }
    
    func resolveStreamURL(videoId: String) async -> URL? {
        let visitorData = await fetchVisitorDataIfNeeded() ?? ""
        
        guard let url = URL(string: "https://www.youtube.com/youtubei/v1/player?prettyPrint=false") else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(visionAgent, forHTTPHeaderField: "User-Agent")
        req.setValue("101", forHTTPHeaderField: "X-YouTube-Client-Name")
        req.setValue("1.02", forHTTPHeaderField: "X-YouTube-Client-Version")
        
        var clientObj: [String: Any] = [
            "clientName": "VISIONOS",
            "clientVersion": "1.02",
            "deviceMake": "Apple",
            "deviceModel": "RealityDevice17,1",
            "osName": "visionOS",
            "osVersion": "26.5.23O471",
            "userAgent": visionAgent,
            "hl": "id",
            "gl": "ID",
            "timeZone": "Asia/Jakarta",
            "utcOffsetMinutes": 420
        ]
        if !visitorData.isEmpty {
            clientObj["visitorData"] = visitorData
        }
        
        let body: [String: Any] = [
            "context": ["client": clientObj],
            "videoId": videoId,
            "playbackContext": ["contentPlaybackContext": ["html5Preference": "HTML5_PREF_WANTS"]],
            "contentCheckOk": true,
            "racyCheckOk": true
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        guard let (data, resp) = try? await session.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        
        guard let streamingData = json["streamingData"] as? [String: Any],
              let formats = streamingData["adaptiveFormats"] as? [[String: Any]] else {
            return nil
        }
        
        let audioFormats = formats.filter { ($0["mimeType"] as? String)?.contains("audio") == true && $0["url"] != nil }
        let selected = audioFormats.first(where: { $0["itag"] as? Int == 140 })
            ?? audioFormats.first(where: { ($0["mimeType"] as? String)?.contains("audio/mp4") == true })
            ?? audioFormats.first
        
        if let directUrlStr = selected?["url"] as? String, let directUrl = URL(string: directUrlStr) {
            return directUrl
        }
        return nil
    }
}
