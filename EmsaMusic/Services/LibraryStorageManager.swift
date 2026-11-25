import Foundation

class LibraryStorageManager: ObservableObject {
    static let shared = LibraryStorageManager()
    
    private let likedKey = "EmsaMusic_LikedSongs"
    private let historyKey = "EmsaMusic_History"
    private let playlistsKey = "EmsaMusic_Playlists"
    
    @Published var likedTracks: [Track] = []
    @Published var historyTracks: [Track] = []
    @Published var customPlaylists: [Playlist] = []
    
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
    
    private func saveLiked() {
        if let data = try? JSONEncoder().encode(likedTracks) {
            UserDefaults.standard.set(data, forKey: likedKey)
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
