import SwiftUI

struct ContentView: View {
    @StateObject private var player = AudioPlayerManager.shared
    @State private var query: String = ""
    @State private var searchResults: [Track] = []
    @State private var isSearching: Bool = false
    @State private var showNowPlayingSheet: Bool = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Color(hex: "090A0F").ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Header & Search Bar
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Image(systemName: "music.note.house.fill")
                            .font(.title2)
                            .foregroundColor(.cyan)
                        Text("MixMusic")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    
                    // Search Field
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Cari lagu, artis, atau album...", text: $query)
                            .foregroundColor(.white)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .onSubmit {
                                performSearch()
                            }
                        if !query.isEmpty {
                            Button(action: { query = ""; searchResults = [] }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(14)
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 12)
                
                // Content List
                if isSearching {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
                        .scaleEffect(1.3)
                    Text("Mencari lagu di YouTube Music & Spotify...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 12)
                    Spacer()
                } else if searchResults.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "music.quarternote.3")
                            .font(.system(size: 48))
                            .foregroundColor(.cyan.opacity(0.6))
                        Text("Mulai dengarkan musik")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("Ketik lagu favoritmu di kolom pencarian di atas.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(searchResults) { track in
                            HStack(spacing: 14) {
                                AsyncImage(url: URL(string: track.thumbnailUrl)) { img in
                                    img.resizable()
                                       .scaledToFill()
                                       .frame(width: 52, height: 52)
                                       .cornerRadius(8)
                                } placeholder: {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(width: 52, height: 52)
                                }
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(track.title)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(player.currentTrack?.id == track.id ? .cyan : .white)
                                        .lineLimit(1)
                                    Text(track.artist)
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                
                                Spacer()
                                
                                if player.currentTrack?.id == track.id && player.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
                                } else if player.currentTrack?.id == track.id && player.isPlaying {
                                    Image(systemName: "waveform")
                                        .foregroundColor(.cyan)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                player.play(track: track)
                            }
                            .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(PlainListStyle())
                    .padding(.bottom, player.currentTrack != nil ? 75 : 0)
                }
            }
            
            // Mini Player Bar (Floating above bottom)
            if let track = player.currentTrack {
                HStack(spacing: 12) {
                    AsyncImage(url: URL(string: track.thumbnailUrl)) { img in
                        img.resizable()
                           .scaledToFill()
                           .frame(width: 44, height: 44)
                           .cornerRadius(6)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 44, height: 44)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.title)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Text(track.artist)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    Button(action: { player.togglePlayPause() }) {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(hex: "181A22").opacity(0.96))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.4), radius: 10, y: 5)
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                .contentShape(Rectangle())
                .onTapGesture {
                    showNowPlayingSheet = true
                }
            }
        }
        .sheet(isPresented: $showNowPlayingSheet) {
            NowPlayingView(isPresented: $showNowPlayingSheet)
        }
    }
    
    private func performSearch() {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSearching = true
        Task {
            do {
                let results = try await YouTubeService.shared.search(query: query)
                await MainActor.run {
                    self.searchResults = results
                    self.isSearching = false
                }
            } catch {
                print("Search error: \(error)")
                await MainActor.run {
                    self.isSearching = false
                }
            }
        }
    }
}
