import Foundation

class LibraryStorageManager: ObservableObject {
    static let shared = LibraryStorageManager()
    
    private let likedKey = "EmsaMusic_LikedSongs"
    private let historyKey = "EmsaMusic_History"
    private let playlistsKey = "EmsaMusic_Playlists"
    private let downloadedKey = "EmsaMusic_Downloaded"
    
    @Published var likedTracks: [Track] = []
    @Published var historyTracks: [Track] = []
    @Published var customPlaylists: [Playlist] = []
    @Published var downloadedTracks: [Track] = []
    
    init() {
        loadData()
    }
    
    private func loadData() {
        let decoder = JSONDecoder()
        
        // 1. Liked
        if let data = UserDefaults.standard.data(forKey: likedKey),
           let list = try? decoder.decode([Track].self, from: data) {
            self.likedTracks = list
        }
        
        // 2. History
        if let data = UserDefaults.standard.data(forKey: historyKey),
           let list = try? decoder.decode([Track].self, from: data) {
            self.historyTracks = list
        }
        
        // 3. Playlists
        if let data = UserDefaults.standard.data(forKey: playlistsKey),
           let list = try? decoder.decode([Playlist].self, from: data) {
            self.customPlaylists = list
        }
        
        // 4. Downloaded Offline
        if let data = UserDefaults.standard.data(forKey: downloadedKey),
           let list = try? decoder.decode([Track].self, from: data) {
            self.downloadedTracks = list
        }
    }
    
    func isLiked(track: Track) -> Bool {
        likedTracks.contains { $0.id == track.id }
    }
    
    func toggleLike(track: Track) {
        if isLiked(track: track) {
            likedTracks.removeAll { $0.id == track.id }
        } else {
            likedTracks.insert(track, at: 0)
        }
        saveLiked()
    }
    
    func isDownloaded(track: Track) -> Bool {
        downloadedTracks.contains { $0.id == track.id }
    }
    
    func toggleDownload(track: Track) {
        if isDownloaded(track: track) {
            downloadedTracks.removeAll { $0.id == track.id }
        } else {
            downloadedTracks.insert(track, at: 0)
        }
        saveDownloaded()
    }
    
    func addToHistory(track: Track) {
        historyTracks.removeAll { $0.id == track.id }
        historyTracks.insert(track, at: 0)
        if historyTracks.count > 50 {
            historyTracks = Array(historyTracks.prefix(50))
        }
        saveHistory()
    }
    
    func createPlaylist(title: String, description: String = "") {
        let p = Playlist(title: title, description: description, tracks: [])
        customPlaylists.insert(p, at: 0)
        savePlaylists()
    }
    
    func addTrackToPlaylist(playlistId: UUID, track: Track) {
        guard let index = customPlaylists.firstIndex(where: { $0.id == playlistId }) else { return }
        if !customPlaylists[index].tracks.contains(where: { $0.id == track.id }) {
            customPlaylists[index].tracks.append(track)
            savePlaylists()
        }
    }
    
    func removeTrackFromPlaylist(playlistId: UUID, trackId: String) {
        guard let index = customPlaylists.firstIndex(where: { $0.id == playlistId }) else { return }
        customPlaylists[index].tracks.removeAll { $0.id == trackId }
        savePlaylists()
    }
    
    func deletePlaylist(playlistId: UUID) {
        customPlaylists.removeAll { $0.id == playlistId }
        savePlaylists()
    }
    
    func renamePlaylist(playlistId: UUID, newTitle: String) {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = customPlaylists.firstIndex(where: { $0.id == playlistId }) else { return }
        customPlaylists[index].title = trimmed
        savePlaylists()
    }
    
    // Import Playlist from Spotify or YouTube URL
    func importPlaylistFromLink(link: String) async -> Bool {
        let clean = link.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return false }
        
        // 1. If it's a Spotify Playlist Link, fetch actual metadata & tracklist from Spotify Embed
        if clean.contains("spotify.com/playlist/") {
            if let playlistId = clean.components(separatedBy: "playlist/").last?.components(separatedBy: "?").first, !playlistId.isEmpty {
                if let (title, tracks) = await fetchSpotifyEmbedPlaylist(id: playlistId), !tracks.isEmpty {
                    await MainActor.run {
                        let imported = Playlist(
                            title: title,
                            description: "Diimpor dari Spotify Playlist",
                            tracks: tracks
                        )
                        self.customPlaylists.insert(imported, at: 0)
                        self.savePlaylists()
                    }
                    return true
                }
            }
        }
        
        // 2. Generic Search Fallback (without 30 cap)
        var query = clean
        if clean.contains("spotify.com") {
            query = "Spotify Hits"
        } else if clean.contains("youtube.com") || clean.contains("youtu.be") {
            query = "Top Music Hits"
        }
        
        do {
            let tracks = try await YouTubeMusicService.shared.search(query: query)
            if !tracks.isEmpty {
                await MainActor.run {
                    let imported = Playlist(
                        title: "Impor: \(query)",
                        description: "Diimpor dari \(clean)",
                        tracks: tracks
                    )
                    self.customPlaylists.insert(imported, at: 0)
                    self.savePlaylists()
                }
                return true
            }
        } catch {
            return false
        }
        return false
    }
    
    private func fetchSpotifyEmbedPlaylist(id: String) async -> (String, [Track])? {
        guard let url = URL(string: "https://open.spotify.com/embed/playlist/\(id)") else { return nil }
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko)", forHTTPHeaderField: "User-Agent")
        
        guard let (data, resp) = try? await URLSession.shared.data(for: request),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let html = String(data: data, encoding: .utf8) else { return nil }
        
        // Extract __NEXT_DATA__ JSON script
        guard let startTag = html.range(of: "<script id=\"__NEXT_DATA__\" type=\"application/json\">"),
              let endTag = html.range(of: "</script>", range: startTag.upperBound..<html.endIndex) else { return nil }
        
        let jsonStr = String(html[startTag.upperBound..<endTag.lowerBound])
        guard let jsonData = jsonStr.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let props = json["props"] as? [String: Any],
              let pageProps = props["pageProps"] as? [String: Any],
              let state = pageProps["state"] as? [String: Any],
              let dataObj = state["data"] as? [String: Any],
              let entity = dataObj["entity"] as? [String: Any] else { return nil }
        
        let playlistTitle = entity["title"] as? String ?? "Spotify Playlist"
        let coverArtObj = entity["coverArt"] as? [String: Any]
        let sources = coverArtObj?["sources"] as? [[String: Any]]
        let playlistCoverUrl = sources?.first?["url"] as? String ?? ""
        
        let trackList = entity["trackList"] as? [[String: Any]] ?? []
        
        var result: [Track] = []
        for item in trackList {
            guard let trackTitle = item["title"] as? String else { continue }
            let artist = item["subtitle"] as? String ?? "Various Artists"
            let durationMs = item["duration"] as? Int ?? 0
            let uri = item["uri"] as? String ?? ""
            let id = uri.components(separatedBy: ":").last ?? UUID().uuidString
            
            result.append(Track(
                id: "sp:\(id)",
                title: trackTitle,
                artist: artist,
                thumbnailUrl: playlistCoverUrl,
                durationSeconds: durationMs > 0 ? durationMs / 1000 : nil
            ))
        }
        
        return (playlistTitle, result)
    }
    
    func updateTrackThumbnail(trackId: String, newThumbnailUrl: String) {
        guard !newThumbnailUrl.isEmpty else { return }
        var modified = false
        for (pIndex, playlist) in customPlaylists.enumerated() {
            for (tIndex, track) in playlist.tracks.enumerated() {
                if track.id == trackId && (track.thumbnailUrl.isEmpty || track.thumbnailUrl != newThumbnailUrl) {
                    customPlaylists[pIndex].tracks[tIndex] = Track(
                        id: track.id,
                        title: track.title,
                        artist: track.artist,
                        thumbnailUrl: newThumbnailUrl,
                        durationSeconds: track.durationSeconds,
                        isKaraokeMode: track.isKaraokeMode
                    )
                    modified = true
                }
            }
        }
        if modified {
            savePlaylists()
        }
    }
    
    private func saveLiked() {
        if let data = try? JSONEncoder().encode(likedTracks) {
            UserDefaults.standard.set(data, forKey: likedKey)
        }
    }
    
    private func saveDownloaded() {
        if let data = try? JSONEncoder().encode(downloadedTracks) {
            UserDefaults.standard.set(data, forKey: downloadedKey)
        }
    }
    
    private func saveHistory() {
        if let data = try? JSONEncoder().encode(historyTracks) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }
    }
    
    private func savePlaylists() {
        if let data = try? JSONEncoder().encode(customPlaylists) {
            UserDefaults.standard.set(data, forKey: playlistsKey)
        }
    }
}
