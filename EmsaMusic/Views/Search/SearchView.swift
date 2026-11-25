import SwiftUI

struct SearchView: View {
    @ObservedObject var player = AudioPlayerManager.shared
    @State private var query: String = ""
    @State private var searchResults: [Track] = []
    @State private var isSearching: Bool = false
    
    let quickTags = ["Nadin Amizah", "Bernadya", "Hindia", "Coldplay", "Tulus", "Sal Priadi"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header & Search Bar
                VStack(alignment: .leading, spacing: 14) {
                    Text("Pencarian")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                    
                    // Search Field
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Cari lagu, artis, atau lirik...", text: $query)
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
                    
                    // Quick Tags
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(quickTags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.white.opacity(0.08))
                                    .cornerRadius(20)
                                    .foregroundColor(.white.opacity(0.85))
                                    .onTapGesture {
                                        query = tag
                                        performSearch()
                                    }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.bottom, 14)
                
                // Content
                if isSearching {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
                        .scaleEffect(1.2)
                    Text("Mencari di YouTube Music...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 12)
                    Spacer()
                } else if searchResults.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "music.note.magnifyingglass")
                            .font(.system(size: 46))
                            .foregroundColor(.white.opacity(0.3))
                        Text("Temukan Musik Tanpa Batas")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("Ketik judul lagu atau nama penyanyi di atas untuk mulai memutar.")
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
                                    img.resizable().scaledToFill().frame(width: 52, height: 52).cornerRadius(8)
                                } placeholder: {
                                    RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.2)).frame(width: 52, height: 52)
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
                                player.play(track: track, fromQueue: searchResults)
                            }
                            .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(PlainListStyle())
                    .padding(.bottom, 75)
                }
            }
            .background(Color(hex: "090A0F").ignoresSafeArea())
            .navigationBarHidden(true)
        }
    }
    
    private func performSearch() {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSearching = true
        Task {
            do {
                let results = try await YouTubeMusicService.shared.search(query: query)
                await MainActor.run {
                    self.searchResults = results
                    self.isSearching = false
                }
            } catch {
                await MainActor.run {
                    self.isSearching = false
                }
            }
        }
    }
}
