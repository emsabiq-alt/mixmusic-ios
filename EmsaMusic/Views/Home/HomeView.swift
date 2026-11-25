import SwiftUI

struct HomeView: View {
    @ObservedObject var player = AudioPlayerManager.shared
    @ObservedObject var library = LibraryStorageManager.shared
    
    @State private var trendingTracks: [Track] = []
    @State private var isLoading: Bool = false
    
    let moods = [
        ("Santai & Chill", "cloud.sun.fill", Color.blue),
        ("Fokus Kerja", "brain.head.profile", Color.purple),
        ("Semangat Olahraga", "flame.fill", Color.orange),
        ("Kopi & Akustik", "cup.and.saucer.fill", Color.brown),
        ("Indie Pop", "sparkles", Color.pink),
        ("Puncak Tangga Lagu", "chart.bar.xaxis", Color.green)
    ]
    
    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 26) {
                    // Header Greeting
                    VStack(alignment: .leading, spacing: 4) {
                        Text(getGreeting())
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("Temukan Musik Favoritmu")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    
                    // Quick Jump Back In (If history exists)
                    if let lastTrack = library.historyTracks.first {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("LANJUTKAN MENDENGARKAN")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(1.5)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 20)
                            
                            HStack(spacing: 14) {
                                AsyncImage(url: URL(string: lastTrack.thumbnailUrl)) { img in
                                    img.resizable().scaledToFill().frame(width: 58, height: 58).cornerRadius(10)
                                } placeholder: {
                                    RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.2)).frame(width: 58, height: 58)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(lastTrack.title)
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    Text(lastTrack.artist)
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                
                                Spacer()
                                
                                Button(action: { player.play(track: lastTrack, fromQueue: library.historyTracks) }) {
                                    Image(systemName: "play.circle.fill")
                                        .font(.system(size: 38))
                                        .foregroundColor(.cyan)
                                }
                            }
                            .padding(14)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(16)
                            .padding(.horizontal, 20)
                        }
                    }
                    
                    // Trending Now Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("SEDANG TREN HARI INI")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(1.5)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button(action: { loadTrending() }) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.caption)
                                    .foregroundColor(.cyan)
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        if isLoading && trendingTracks.isEmpty {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
                                    .padding(.vertical, 30)
                                Spacer()
                            }
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 14) {
                                    ForEach(trendingTracks) { track in
                                        VStack(alignment: .leading, spacing: 8) {
                                            AsyncImage(url: URL(string: track.thumbnailUrl)) { img in
                                                img.resizable().scaledToFill().frame(width: 140, height: 140).cornerRadius(14)
                                            } placeholder: {
                                                RoundedRectangle(cornerRadius: 14).fill(Color.gray.opacity(0.2)).frame(width: 140, height: 140)
                                            }
                                            
                                            Text(track.title)
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundColor(.white)
                                                .lineLimit(1)
                                                .frame(width: 140, alignment: .leading)
                                            Text(track.artist)
                                                .font(.system(size: 11))
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                                .frame(width: 140, alignment: .leading)
                                        }
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            player.play(track: track, fromQueue: trendingTracks)
                                        }
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                    }
                    
                    // Moods & Genres Grid
                    VStack(alignment: .leading, spacing: 12) {
                        Text("SUASANA HATI & GENRE")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1.5)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(moods, id: \.0) { mood in
                                HStack {
                                    Image(systemName: mood.1)
                                        .font(.title3)
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text(mood.0)
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                .padding(16)
                                .background(mood.2.opacity(0.35))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(mood.2.opacity(0.5), lineWidth: 1))
                                .cornerRadius(14)
                                .onTapGesture {
                                    playGenre(mood.0)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    Spacer(minLength: 80)
                }
            }
            .background(Color(hex: "090A0F").ignoresSafeArea())
            .navigationBarHidden(true)
        }
        .onAppear {
            if trendingTracks.isEmpty {
                loadTrending()
            }
        }
    }
    
    private func getGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 11 { return "Selamat Pagi 🌅" }
        if hour < 15 { return "Selamat Siang ☀️" }
        if hour < 18 { return "Selamat Sore ☕" }
        return "Selamat Malam 🌙"
    }
    
    private func loadTrending() {
        isLoading = true
        Task {
            let tracks = await YouTubeMusicService.shared.fetchTrending()
            await MainActor.run {
                self.trendingTracks = tracks
                self.isLoading = false
            }
        }
    }
    
    private func playGenre(_ genre: String) {
        Task {
            if let tracks = try? await YouTubeMusicService.shared.search(query: "\(genre) songs 2026"), let first = tracks.first {
                await MainActor.run {
                    self.player.play(track: first, fromQueue: tracks)
                }
            }
        }
    }
}
