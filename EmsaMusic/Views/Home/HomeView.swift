import SwiftUI

struct HomeView: View {
    @ObservedObject var player = AudioPlayerManager.shared
    @ObservedObject var library = LibraryStorageManager.shared
    
    @State private var top50Tracks: [Track] = []
    @State private var trendingTracks: [Track] = []
    @State private var isLoading: Bool = false
    
    private let spotifyGreen = Color(hex: "1DB954")
    
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
                    // 1. Header Greeting
                    VStack(alignment: .leading, spacing: 4) {
                        Text(getGreeting())
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color(hex: "B3B3B3"))
                        Text("EmsaMusic")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    
                    // 2. Top 50 Indonesia Chart Banner (Spotlight)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("TANGGA LAGU RESMI")
                                    .font(.system(size: 10, weight: .bold))
                                    .tracking(1.4)
                                    .foregroundColor(spotifyGreen)
                                Text("Top 50 Indonesia 🇮🇩")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            Spacer()
                            
                            if !top50Tracks.isEmpty {
                                NavigationLink(destination: PlaylistDetailView(title: "Top 50 Indonesia", tracks: top50Tracks)) {
                                    Text("Lihat Semua")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(spotifyGreen)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Color.white.opacity(0.08))
                                        .cornerRadius(12)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        if top50Tracks.isEmpty && isLoading {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: spotifyGreen))
                                    .padding(.vertical, 30)
                                Spacer()
                            }
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 14) {
                                    ForEach(Array(top50Tracks.prefix(15).enumerated()), id: \.element.id) { index, track in
                                        VStack(alignment: .leading, spacing: 8) {
                                            ZStack(alignment: .topLeading) {
                                                AsyncImage(url: URL(string: track.thumbnailUrl)) { img in
                                                    img.resizable().scaledToFill().frame(width: 140, height: 140).cornerRadius(8)
                                                } placeholder: {
                                                    RoundedRectangle(cornerRadius: 8).fill(Color(hex: "282828")).frame(width: 140, height: 140)
                                                }
                                                
                                                // Rank Badge #1, #2, #3
                                                Text("#\(index + 1)")
                                                    .font(.system(size: 11, weight: .black))
                                                    .foregroundColor(.white)
                                                    .padding(.horizontal, 7)
                                                    .padding(.vertical, 4)
                                                    .background(index < 3 ? spotifyGreen : Color.black.opacity(0.75))
                                                    .cornerRadius(6)
                                                    .padding(6)
                                            }
                                            
                                            Text(track.title)
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundColor(.white)
                                                .lineLimit(1)
                                                .frame(width: 140, alignment: .leading)
                                            Text(track.artist)
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundColor(Color(hex: "B3B3B3"))
                                                .lineLimit(1)
                                                .frame(width: 140, alignment: .leading)
                                        }
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            player.play(track: track, fromQueue: top50Tracks)
                                        }
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                    }
                    
                    // 3. Quick Jump Back In (If history exists)
                    if let lastTrack = library.historyTracks.first {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("LANJUTKAN MENDENGARKAN")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(1.4)
                                .foregroundColor(Color(hex: "B3B3B3"))
                                .padding(.horizontal, 20)
                            
                            HStack(spacing: 14) {
                                AsyncImage(url: URL(string: lastTrack.thumbnailUrl)) { img in
                                    img.resizable().scaledToFill().frame(width: 54, height: 54).cornerRadius(8)
                                } placeholder: {
                                    RoundedRectangle(cornerRadius: 8).fill(Color(hex: "282828")).frame(width: 54, height: 54)
                                }
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(lastTrack.title)
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    Text(lastTrack.artist)
                                        .font(.system(size: 13))
                                        .foregroundColor(Color(hex: "B3B3B3"))
                                        .lineLimit(1)
                                }
                                
                                Spacer()
                                
                                Button(action: { player.play(track: lastTrack, fromQueue: library.historyTracks) }) {
                                    Image(systemName: "play.circle.fill")
                                        .font(.system(size: 38))
                                        .foregroundColor(spotifyGreen)
                                }
                            }
                            .padding(12)
                            .background(Color(hex: "1F1F1F"))
                            .cornerRadius(12)
                            .padding(.horizontal, 20)
                        }
                    }
                    
                    // 4. Trending Hits
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("VIRAL HITS HARI INI")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(1.4)
                                .foregroundColor(Color(hex: "B3B3B3"))
                            Spacer()
                            Button(action: { loadData() }) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.caption)
                                    .foregroundColor(spotifyGreen)
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 14) {
                                ForEach(trendingTracks) { track in
                                    VStack(alignment: .leading, spacing: 8) {
                                        AsyncImage(url: URL(string: track.thumbnailUrl)) { img in
                                            img.resizable().scaledToFill().frame(width: 140, height: 140).cornerRadius(8)
                                        } placeholder: {
                                            RoundedRectangle(cornerRadius: 8).fill(Color(hex: "282828")).frame(width: 140, height: 140)
                                        }
                                        
                                        Text(track.title)
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                            .frame(width: 140, alignment: .leading)
                                        Text(track.artist)
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(Color(hex: "B3B3B3"))
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
                    
                    // 5. Moods & Genres Grid
                    VStack(alignment: .leading, spacing: 12) {
                        Text("SUASANA HATI & GENRE")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1.4)
                            .foregroundColor(Color(hex: "B3B3B3"))
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
                                .background(mood.2.opacity(0.3))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(mood.2.opacity(0.4), lineWidth: 1))
                                .cornerRadius(12)
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
            .background(Color(hex: "121212").ignoresSafeArea())
            .navigationBarHidden(true)
        }
        .onAppear {
            if top50Tracks.isEmpty {
                loadData()
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
    
    private func loadData() {
        isLoading = true
        Task {
            async let top50 = YouTubeMusicService.shared.fetchTop50Indonesia()
            async let trending = YouTubeMusicService.shared.fetchTrending()
            
            let (topRes, trendRes) = await (top50, trending)
            await MainActor.run {
                self.top50Tracks = topRes
                self.trendingTracks = trendRes
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
