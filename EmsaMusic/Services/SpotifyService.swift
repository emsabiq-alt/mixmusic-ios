import Foundation
import CryptoKit
import AuthenticationServices
import SwiftUI

struct SpotifyUserProfile: Codable, Equatable {
    let id: String?
    let display_name: String?
    let email: String?
    let images: [SpotifyImage]?
}

struct SpotifyImage: Codable, Equatable {
    let url: String
}

struct SpotifyPlaylist: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let description: String?
    let images: [SpotifyImage]?
    let tracks: SpotifyPlaylistTracksInfo?
}

struct SpotifyPlaylistTracksInfo: Codable, Equatable {
    let total: Int
}

class SpotifyService: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = SpotifyService()
    
    let clientId = "5e98adbd48744236a380dca10ee8a36a"
    let redirectUri = "emsamusic://callback"
    
    @Published var isLoggedIn: Bool = false
    @Published var userProfile: SpotifyUserProfile? = nil
    @Published var userPlaylists: [SpotifyPlaylist] = []
    @Published var likedTracks: [Track] = []
    @Published var isLoading: Bool = false
    
    private var accessToken: String? {
        get { UserDefaults.standard.string(forKey: "spotify_access_token") }
        set { 
            UserDefaults.standard.set(newValue, forKey: "spotify_access_token")
            DispatchQueue.main.async { self.isLoggedIn = newValue != nil }
        }
    }
    
    private var refreshToken: String? {
        get { UserDefaults.standard.string(forKey: "spotify_refresh_token") }
        set { UserDefaults.standard.set(newValue, forKey: "spotify_refresh_token") }
    }
    
    private var codeVerifier: String = ""
    
    override init() {
        super.init()
        if accessToken != nil {
            self.isLoggedIn = true
            Task {
                await loadAllData()
            }
        }
    }
    
    // MARK: - PKCE Authentication
    func startLogin() {
        codeVerifier = generateCodeVerifier()
        let codeChallenge = generateCodeChallenge(from: codeVerifier)
        
        let scopes = "user-read-private user-read-email playlist-read-private playlist-read-collaborative user-library-read"
        guard let encodedScopes = scopes.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let encodedRedirect = redirectUri.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return }
        
        let authUrlStr = "https://accounts.spotify.com/authorize?client_id=\(clientId)&response_type=code&redirect_uri=\(encodedRedirect)&code_challenge_method=S256&code_challenge=\(codeChallenge)&scope=\(encodedScopes)&show_dialog=true"
        
        guard let authUrl = URL(string: authUrlStr) else { return }
        
        let session = ASWebAuthenticationSession(url: authUrl, callbackURLScheme: "emsamusic") { [weak self] callbackURL, error in
            guard error == nil, let url = callbackURL else {
                print("[Spotify] Auth error or cancelled: \(String(describing: error))")
                return
            }
            
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let code = components.queryItems?.first(where: { $0.name == "code" })?.value {
                Task {
                    await self?.exchangeCodeForToken(code: code)
                }
            }
        }
        
        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = true
        session.start()
    }
    
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
    
    private func exchangeCodeForToken(code: String) async {
        guard let url = URL(string: "https://accounts.spotify.com/api/token") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let bodyParams = [
            "client_id": clientId,
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": redirectUri,
            "code_verifier": codeVerifier
        ]
        
        let bodyString = bodyParams.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }.joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let token = json["access_token"] as? String {
                self.accessToken = token
                if let ref = json["refresh_token"] as? String {
                    self.refreshToken = ref
                }
                await loadAllData()
            }
        } catch {
            print("[Spotify] Token exchange failed: \(error)")
        }
    }
    
    func logout() {
        accessToken = nil
        refreshToken = nil
        userProfile = nil
        userPlaylists = []
        likedTracks = []
        isLoggedIn = false
    }
    
    // MARK: - Data Fetching
    func loadAllData() async {
        await MainActor.run { self.isLoading = true }
        await fetchProfile()
        await fetchPlaylists()
        await fetchLikedSongs()
        await MainActor.run { self.isLoading = false }
    }
    
    func fetchProfile() async {
        guard let token = accessToken, let url = URL(string: "https://api.spotify.com/v1/me") else { return }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        if let (data, resp) = try? await URLSession.shared.data(for: req),
           (resp as? HTTPURLResponse)?.statusCode == 200,
           let profile = try? JSONDecoder().decode(SpotifyUserProfile.self, from: data) {
            await MainActor.run { self.userProfile = profile }
        }
    }
    
    func fetchPlaylists() async {
        guard let token = accessToken, let url = URL(string: "https://api.spotify.com/v1/me/playlists?limit=50") else { return }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        if let (data, resp) = try? await URLSession.shared.data(for: req),
           (resp as? HTTPURLResponse)?.statusCode == 200,
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let itemsData = try? JSONSerialization.data(withJSONObject: json["items"] ?? []),
           let playlists = try? JSONDecoder().decode([SpotifyPlaylist].self, from: itemsData) {
            await MainActor.run { self.userPlaylists = playlists }
        }
    }
    
    func fetchLikedSongs() async {
        guard let token = accessToken, let url = URL(string: "https://api.spotify.com/v1/me/tracks?limit=50") else { return }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        if let (data, resp) = try? await URLSession.shared.data(for: req),
           (resp as? HTTPURLResponse)?.statusCode == 200,
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let items = json["items"] as? [[String: Any]] {
            
            var parsed: [Track] = []
            for item in items {
                guard let t = item["track"] as? [String: Any],
                      let id = t["id"] as? String,
                      let name = t["name"] as? String else { continue }
                
                var artistName = "Various Artists"
                if let artists = t["artists"] as? [[String: Any]], let first = artists.first?["name"] as? String {
                    artistName = first
                }
                
                var thumb = ""
                if let album = t["album"] as? [String: Any],
                   let images = album["images"] as? [[String: Any]],
                   let firstImg = images.first?["url"] as? String {
                    thumb = firstImg
                }
                
                let durationMs = t["duration_ms"] as? Int ?? 0
                parsed.append(Track(id: "sp:\(id)", title: name, artist: artistName, thumbnailUrl: thumb, durationSeconds: durationMs / 1000))
            }
            
            await MainActor.run { self.likedTracks = parsed }
        }
    }
    
    func fetchPlaylistTracks(playlistId: String) async -> [Track] {
        guard let token = accessToken, let url = URL(string: "https://api.spotify.com/v1/playlists/\(playlistId)/tracks?limit=50") else { return [] }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["items"] as? [[String: Any]] else { return [] }
        
        var parsed: [Track] = []
        for item in items {
            guard let t = item["track"] as? [String: Any],
                  let id = t["id"] as? String,
                  let name = t["name"] as? String else { continue }
            
            var artistName = "Various Artists"
            if let artists = t["artists"] as? [[String: Any]], let first = artists.first?["name"] as? String {
                artistName = first
            }
            
            var thumb = ""
            if let album = t["album"] as? [String: Any],
               let images = album["images"] as? [[String: Any]],
               let firstImg = images.first?["url"] as? String {
                thumb = firstImg
            }
            
            let durationMs = t["duration_ms"] as? Int ?? 0
            parsed.append(Track(id: "sp:\(id)", title: name, artist: artistName, thumbnailUrl: thumb, durationSeconds: durationMs / 1000))
        }
        return parsed
    }
    
    // MARK: - PKCE Helpers
    private func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 64)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
            .trimmingCharacters(in: .whitespaces)
    }
    
    private func generateCodeChallenge(from verifier: String) -> String {
        guard let data = verifier.data(using: .utf8) else { return "" }
        let hash = SHA256.hash(data: data)
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
            .trimmingCharacters(in: .whitespaces)
    }
}
