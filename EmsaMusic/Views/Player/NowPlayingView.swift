import SwiftUI

struct NowPlayingView: View {
    @ObservedObject var player = AudioPlayerManager.shared
    @ObservedObject var library = LibraryStorageManager.shared
    @Binding var isPresented: Bool
    
    @State private var showLyrics: Bool = false
    @State private var showQueue: Bool = false
    @State private var showSpeedSheet: Bool = false
    @State private var showSleepSheet: Bool = false
    @State private var showEqualizerSheet: Bool = false
    @State private var isDraggingSlider: Bool = false
    @State private var dragPosition: Double = 0.0
    
    // Spotify Signature Palette
    private let spotifyGreen = Color(hex: "1DB954")
    private let spotifyBgTop = Color(hex: "22252C")
    private let spotifyBgBottom = Color(hex: "121212")
    
    var body: some View {
        GeometryReader { geo in
            let sidePadding: CGFloat = 24
            let artWidth = geo.size.width - (sidePadding * 2)
            
            ZStack {
                // 1. Dynamic Artwork Ambient Aura (Apple Music & Spotify Live Ambient)
                if let cachedImg = player.cachedArtwork {
                    Image(uiImage: cachedImg)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .blur(radius: 65)
                        .opacity(0.38)
                        .ignoresSafeArea()
                } else if let track = player.currentTrack, !track.thumbnailUrl.isEmpty, let url = URL(string: track.thumbnailUrl) {
                    AsyncImage(url: url) { img in
                        img.resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                            .blur(radius: 65)
                            .opacity(0.38)
                    } placeholder: {
                        EmptyView()
                    }
                    .ignoresSafeArea()
                }
                
                // Spotify Vertical Atmospheric Gradient Overlay
                LinearGradient(
                    gradient: Gradient(colors: [spotifyBgTop.opacity(0.85), spotifyBgBottom]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 1. Top Bar
                    HStack {
                        Button(action: { isPresented = false }) {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                        }
                        
                        Spacer()
                        
                        VStack(spacing: 2) {
                            if player.isKaraokeMode {
                                HStack(spacing: 4) {
                                    Image(systemName: "mic.fill")
                                        .font(.system(size: 9))
                                    Text("MODE KARAOKE AKTIF")
                                        .font(.system(size: 10, weight: .black))
                                        .tracking(1.2)
                                }
                                .foregroundColor(Color(hex: "FF2E93"))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color(hex: "FF2E93").opacity(0.2))
                                .cornerRadius(8)
                            } else {
                                Text("MEMUTAR DARI KOLEKSI")
                                    .font(.system(size: 10, weight: .bold))
                                    .tracking(1.2)
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            
                            Text(player.currentTrack?.artist ?? "EmsaMusic")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        Menu {
                            Button(action: { showEqualizerSheet = true }) {
                                Label("Equalizer: \(player.equalizerPreset.rawValue)", systemImage: "slider.vertical.3")
                            }
                            Button(action: { showSpeedSheet = true }) {
                                Label("Kecepatan: \(String(format: "%.2fx", player.playbackSpeed))", systemImage: "gauge.with.needle")
                            }
                            Button(action: { showSleepSheet = true }) {
                                Label("Sleep Timer: \(player.sleepTimerOption.rawValue)", systemImage: "moon.stars")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    
                    Spacer(minLength: 12)
                    
                    // 2. Middle Content (Artwork vs Lyrics vs Queue)
                    if showLyrics {
                        LyricsView()
                            .frame(maxWidth: .infinity, maxHeight: artWidth + 30)
                            .transition(.opacity)
                    } else if showQueue {
                        QueueView()
                            .frame(maxWidth: .infinity, maxHeight: artWidth + 30)
                            .transition(.opacity)
                    } else {
                        // Spotify Perfect Square Artwork
                        if let cachedImg = player.cachedArtwork {
                            Image(uiImage: cachedImg)
                                .resizable()
                                .scaledToFill()
                                .frame(width: artWidth, height: artWidth)
                                .cornerRadius(8)
                                .shadow(color: .black.opacity(0.5), radius: 24, x: 0, y: 14)
                        } else if let track = player.currentTrack, !track.thumbnailUrl.isEmpty, let url = URL(string: track.thumbnailUrl) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: artWidth, height: artWidth)
                                        .cornerRadius(8)
                                        .shadow(color: .black.opacity(0.5), radius: 24, x: 0, y: 14)
                                case .failure(_), .empty:
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color(hex: "282828"))
                                        Image(systemName: "music.note")
                                            .font(.system(size: 48))
                                            .foregroundColor(Color(hex: "535353"))
                                    }
                                    .frame(width: artWidth, height: artWidth)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        } else {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(hex: "282828"))
                                Image(systemName: "music.note")
                                    .font(.system(size: 48))
                                    .foregroundColor(Color(hex: "535353"))
                            }
                            .frame(width: artWidth, height: artWidth)
                        }
                    }
                    
                    Spacer(minLength: 16)
                    
                    // 3. Track Title, Offline Download & Heart Row
                    if let track = player.currentTrack {
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(track.title)
                                    .font(.system(size: 21, weight: .bold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                Text(track.artist)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(Color(hex: "B3B3B3"))
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            // Download Offline Button
                            Button(action: { library.toggleDownload(track: track) }) {
                                Image(systemName: library.isDownloaded(track: track) ? "arrow.down.circle.fill" : "arrow.down.circle")
                                    .font(.system(size: 22))
                                    .foregroundColor(library.isDownloaded(track: track) ? spotifyGreen : Color(hex: "B3B3B3"))
                                    .frame(width: 40, height: 44)
                            }
                            
                            // Heart Liked Button
                            Button(action: { library.toggleLike(track: track) }) {
                                Image(systemName: library.isLiked(track: track) ? "heart.fill" : "heart")
                                    .font(.system(size: 22))
                                    .foregroundColor(library.isLiked(track: track) ? spotifyGreen : Color(hex: "B3B3B3"))
                                    .frame(width: 40, height: 44)
                            }
                        }
                        .padding(.horizontal, sidePadding)
                    }
                    
                    Spacer(minLength: 12)
                    
                    // 4. Scrubber Slider & Times (Spotify Scrubbing Architecture)
                    VStack(spacing: 4) {
                        Slider(
                            value: Binding(
                                get: { isDraggingSlider ? dragPosition : player.currentTime },
                                set: { dragPosition = $0 }
                            ),
                            in: 0...max(player.duration, 1),
                            onEditingChanged: { editing in
                                isDraggingSlider = editing
                                if !editing {
                                    player.seek(to: dragPosition)
                                }
                            }
                        )
                        .accentColor(spotifyGreen)
                        
                        HStack {
                            Text(formatTime(isDraggingSlider ? dragPosition : player.currentTime))
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(Color(hex: "B3B3B3"))
                            Spacer()
                            Text(formatTime(player.duration))
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(Color(hex: "B3B3B3"))
                        }
                    }
                    .padding(.horizontal, sidePadding)
                    
                    Spacer(minLength: 10)
                    
                    // 5. Main Spotify Transport Controls
                    HStack {
                        // Shuffle
                        Button(action: { player.toggleShuffle() }) {
                            VStack(spacing: 3) {
                                Image(systemName: "shuffle")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(player.isShuffle ? spotifyGreen : Color(hex: "B3B3B3"))
                                Circle()
                                    .fill(player.isShuffle ? spotifyGreen : Color.clear)
                                    .frame(width: 4, height: 4)
                            }
                            .frame(width: 40, height: 40)
                        }
                        
                        Spacer()
                        
                        // Previous
                        Button(action: { player.playPrevious() }) {
                            Image(systemName: "backward.end.fill")
                                .font(.system(size: 26))
                                .foregroundColor(.white)
                                .frame(width: 48, height: 48)
                        }
                        
                        Spacer()
                        
                        // Signature Spotify Solid White Play/Pause Button
                        Button(action: { player.togglePlayPause() }) {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 64, height: 64)
                                    .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                                
                                if player.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                } else {
                                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(.black)
                                        .offset(x: player.isPlaying ? 0 : 2)
                                }
                            }
                        }
                        
                        Spacer()
                        
                        // Next
                        Button(action: { player.playNext() }) {
                            Image(systemName: "forward.end.fill")
                                .font(.system(size: 26))
                                .foregroundColor(.white)
                                .frame(width: 48, height: 48)
                        }
                        
                        Spacer()
                        
                        // Repeat
                        Button(action: { player.cycleRepeatMode() }) {
                            VStack(spacing: 3) {
                                Image(systemName: player.repeatMode.iconName)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(player.repeatMode != .off ? spotifyGreen : Color(hex: "B3B3B3"))
                                Circle()
                                    .fill(player.repeatMode != .off ? spotifyGreen : Color.clear)
                                    .frame(width: 4, height: 4)
                            }
                            .frame(width: 40, height: 40)
                        }
                    }
                    .padding(.horizontal, sidePadding)
                    
                    Spacer(minLength: 16)
                    
                    // 6. Bottom Utilities (Karaoke Mic, Speaker, Lyrics & Queue toggles)
                    HStack {
                        // Karaoke Mode Toggle Button
                        Button(action: {
                            withAnimation(.spring()) {
                                player.toggleKaraokeMode()
                                if player.isKaraokeMode {
                                    showLyrics = true
                                    showQueue = false
                                }
                            }
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: player.isKaraokeMode ? "mic.fill" : "mic")
                                Text(player.isKaraokeMode ? "Karaoke ON" : "Karaoke")
                            }
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(player.isKaraokeMode ? Color(hex: "FF2E93") : Color(hex: "B3B3B3"))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(player.isKaraokeMode ? Color(hex: "FF2E93").opacity(0.2) : Color.white.opacity(0.08))
                            .cornerRadius(14)
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 16) {
                            Button(action: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    showLyrics.toggle()
                                    if showLyrics { showQueue = false }
                                }
                            }) {
                                Image(systemName: showLyrics ? "quote.bubble.fill" : "quote.bubble")
                                    .font(.system(size: 18))
                                    .foregroundColor(showLyrics ? spotifyGreen : Color(hex: "B3B3B3"))
                            }
                            
                            Button(action: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    showQueue.toggle()
                                    if showQueue { showLyrics = false }
                                }
                            }) {
                                Image(systemName: showQueue ? "list.bullet.circle.fill" : "list.bullet")
                                    .font(.system(size: 18))
                                    .foregroundColor(showQueue ? spotifyGreen : Color(hex: "B3B3B3"))
                            }
                        }
                    }
                    .padding(.horizontal, sidePadding)
                    .padding(.bottom, 20)
                }
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
        .actionSheet(isPresented: $showEqualizerSheet) {
            ActionSheet(title: Text("Equalizer & Audio Preset"), message: Text("Pilih karakter suara yang kamu sukai:"), buttons: EqualizerPreset.allCases.map { preset in
                .default(Text(preset.rawValue)) { player.setEqualizerPreset(preset) }
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
