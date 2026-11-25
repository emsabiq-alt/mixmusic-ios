import SwiftUI

struct NowPlayingView: View {
    @ObservedObject var player = AudioPlayerManager.shared
    @ObservedObject var library = LibraryStorageManager.shared
    @Binding var isPresented: Bool
    
    @State private var showLyrics: Bool = false
    @State private var showQueue: Bool = false
    @State private var showSpeedSheet: Bool = false
    @State private var showSleepSheet: Bool = false
    
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
            
            VStack(spacing: 20) {
                // Top Navigation Bar
                HStack {
                    Button(action: { isPresented = false }) {
                        Image(systemName: "chevron.down")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(8)
                    }
                    Spacer()
                    VStack(spacing: 2) {
                        Text("SEDANG DIPUTAR")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1.5)
                            .foregroundColor(.white.opacity(0.6))
                        if player.sleepTimerOption != .off {
                            Text("🌙 Sleep Timer: \(formatTime(player.sleepTimerRemainingSeconds))")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.cyan)
                        }
                    }
                    Spacer()
                    HStack(spacing: 4) {
                        Button(action: {
                            showLyrics.toggle()
                            if showLyrics { showQueue = false }
                        }) {
                            Image(systemName: showLyrics ? "quote.bubble.fill" : "quote.bubble")
                                .font(.title3)
                                .foregroundColor(showLyrics ? .cyan : .white)
                                .padding(8)
                        }
                        Button(action: {
                            showQueue.toggle()
                            if showQueue { showLyrics = false }
                        }) {
                            Image(systemName: showQueue ? "list.bullet.circle.fill" : "list.bullet")
                                .font(.title3)
                                .foregroundColor(showQueue ? .cyan : .white)
                                .padding(8)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                
                // Middle View (Artwork vs Lyrics vs Queue)
                if showLyrics {
                    LyricsView()
                        .transition(.opacity)
                } else if showQueue {
                    QueueView()
                        .transition(.opacity)
                } else {
                    Spacer()
                    if let track = player.currentTrack, let url = URL(string: track.thumbnailUrl) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: 320, maxHeight: 320)
                                .cornerRadius(20)
                                .shadow(color: .black.opacity(0.55), radius: 25, x: 0, y: 15)
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 300, height: 300)
                        }
                    }
                    Spacer()
                }
                
                // Track Info & Like Button
                if let track = player.currentTrack {
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
                        Button(action: { library.toggleLike(track: track) }) {
                            Image(systemName: library.isLiked(track: track) ? "heart.fill" : "heart")
                                .font(.title2)
                                .foregroundColor(library.isLiked(track: track) ? .red : .white)
                        }
                    }
                    .padding(.horizontal, 28)
                }
                
                // Scrubber Bar
                VStack(spacing: 6) {
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
                HStack(spacing: 36) {
                    // Shuffle
                    Button(action: { player.toggleShuffle() }) {
                        Image(systemName: "shuffle")
                            .font(.title3)
                            .foregroundColor(player.isShuffle ? .cyan : .white.opacity(0.5))
                    }
                    
                    // Previous
                    Button(action: { player.playPrevious() }) {
                        Image(systemName: "backward.fill")
                            .font(.title)
                            .foregroundColor(.white)
                    }
                    
                    // Play/Pause
                    Button(action: { player.togglePlayPause() }) {
                        ZStack {
                            Circle()
                                .fill(Color.cyan)
                                .frame(width: 72, height: 72)
                            if player.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .black))
                            } else {
                                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.title)
                                    .foregroundColor(.black)
                            }
                        }
                    }
                    
                    // Next
                    Button(action: { player.playNext() }) {
                        Image(systemName: "forward.fill")
                            .font(.title)
                            .foregroundColor(.white)
                    }
                    
                    // Repeat
                    Button(action: { player.cycleRepeatMode() }) {
                        Image(systemName: player.repeatMode.iconName)
                            .font(.title3)
                            .foregroundColor(player.repeatMode != .off ? .cyan : .white.opacity(0.5))
                    }
                }
                
                // Bottom Secondary Controls (Speed & Sleep Timer)
                HStack(spacing: 32) {
                    Button(action: { showSpeedSheet = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "gauge.with.needle")
                            Text(String(format: "%.2fx", player.playbackSpeed))
                        }
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                        .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Button(action: { showSleepSheet = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "moon.stars.fill")
                            Text(player.sleepTimerOption.rawValue)
                        }
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                        .foregroundColor(player.sleepTimerOption != .off ? .cyan : .white.opacity(0.8))
                    }
                }
                .padding(.bottom, 24)
            }
        }
        .actionSheet(isPresented: $showSpeedSheet) {
            ActionSheet(title: Text("Kecepatan Putar"), buttons: [
                .default(Text("0.75x")) { player.setPlaybackSpeed(0.75) },
                .default(Text("1.0x (Normal)")) { player.setPlaybackSpeed(1.0) },
                .default(Text("1.25x")) { player.setPlaybackSpeed(1.25) },
                .default(Text("1.5x")) { player.setPlaybackSpeed(1.5) },
                .cancel()
            ])
        }
        .actionSheet(isPresented: $showSleepSheet) {
            ActionSheet(title: Text("Sleep Timer (Otomatis Berhenti)"), buttons: SleepTimerOption.allCases.map { opt in
                .default(Text(opt.rawValue)) { player.setSleepTimer(option: opt) }
            } + [.cancel()])
        }
    }
    
    private func formatTime(_ sec: TimeInterval) -> String {
        let total = max(0, Int(sec))
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}
