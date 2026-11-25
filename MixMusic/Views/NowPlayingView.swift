import SwiftUI

struct NowPlayingView: View {
    @ObservedObject var player = AudioPlayerManager.shared
    @Binding var isPresented: Bool
    @State private var showLyrics: Bool = false
    
    var body: some View {
        ZStack {
            // Blurred background artwork
            if let track = player.currentTrack, let url = URL(string: track.thumbnailUrl) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .scaledToFill()
                            .overlay(.ultraThinMaterial)
                            .ignoresSafeArea()
                    } else {
                        Color(hex: "0D0D12").ignoresSafeArea()
                    }
                }
            } else {
                Color(hex: "0D0D12").ignoresSafeArea()
            }
            
            VStack(spacing: 24) {
                // Header bar
                HStack {
                    Button(action: { isPresented = false }) {
                        Image(systemName: "chevron.down")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(8)
                    }
                    Spacer()
                    Text("SEDANG DIPUTAR")
                        .font(.caption)
                        .fontWeight(.bold)
                        .tracking(1.5)
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                    Button(action: { showLyrics.toggle() }) {
                        Image(systemName: showLyrics ? "quote.bubble.fill" : "quote.bubble")
                            .font(.title3)
                            .foregroundColor(showLyrics ? .cyan : .white)
                            .padding(8)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                if showLyrics {
                    LyricsView()
                        .transition(.opacity)
                } else {
                    // Artwork Album
                    Spacer()
                    if let track = player.currentTrack, let url = URL(string: track.thumbnailUrl) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: 320, maxHeight: 320)
                                .cornerRadius(20)
                                .shadow(color: .black.opacity(0.5), radius: 25, x: 0, y: 15)
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 300, height: 300)
                        }
                    }
                    Spacer()
                }
                
                // Track Info
                if let track = player.currentTrack {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(track.title)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                Text(track.artist)
                                    .font(.body)
                                    .foregroundColor(.white.opacity(0.7))
                                    .lineLimit(1)
                            }
                            Spacer()
                            Button(action: {}) {
                                Image(systemName: "heart")
                                    .font(.title3)
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .padding(.horizontal, 28)
                }
                
                // Scrubber Bar
                VStack(spacing: 8) {
                    Slider(value: Binding(
                        get: { player.currentTime },
                        set: { player.seek(to: $0) }
                    ), in: 0...max(player.duration, 1))
                    .accentColor(.cyan)
                    
                    HStack {
                        Text(formatTime(player.currentTime))
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                        Spacer()
                        Text(formatTime(player.duration))
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .padding(.horizontal, 28)
                
                // Playback Controls
                HStack(spacing: 45) {
                    Button(action: {}) {
                        Image(systemName: "backward.fill")
                            .font(.title)
                            .foregroundColor(.white)
                    }
                    
                    Button(action: { player.togglePlayPause() }) {
                        ZStack {
                            Circle()
                                .fill(Color.cyan)
                                .frame(width: 72, height: 72)
                            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                .font(.title)
                                .foregroundColor(.black)
                        }
                    }
                    
                    Button(action: {}) {
                        Image(systemName: "forward.fill")
                            .font(.title)
                            .foregroundColor(.white)
                    }
                }
                .padding(.bottom, 36)
            }
        }
    }
    
    private func formatTime(_ sec: TimeInterval) -> String {
        let total = Int(sec)
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)
        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double(rgbValue & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
