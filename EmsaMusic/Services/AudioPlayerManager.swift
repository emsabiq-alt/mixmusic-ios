import Foundation
import AVFoundation
import MediaPlayer
import UIKit

class AudioPlayerManager: ObservableObject {
    static let shared = AudioPlayerManager()
    
    // Pure Native AVPlayer Engine
    private var avPlayer: AVPlayer?
    private var timeObserver: Any?
    private var endObserver: Any?
    private var sleepTimer: Timer?
    private var cachedArtwork: UIImage?
    
    // Preload Cache for Gapless Next Track
    private var preloadedTrackId: String? = nil
    private var preloadedStreamUrl: URL? = nil
    private var isTransitioning: Bool = false
    
    @Published var currentTrack: Track?
    @Published var queue: [Track] = []
    @Published var originalQueue: [Track] = []
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var officialTrackDuration: TimeInterval? = nil
    @Published var lyrics: [LyricLine] = []
    @Published var currentLyricIndex: Int = 0
    @Published var lyricsOffset: Double = 0.0
    @Published var isLoading: Bool = false
    
    @Published var isShuffle: Bool = false
    @Published var repeatMode: RepeatMode = .off
    @Published var playbackSpeed: Float = 1.0
    @Published var sleepTimerOption: SleepTimerOption = .off
    @Published var sleepTimerRemainingSeconds: TimeInterval = 0
    @Published var isKaraokeMode: Bool = false
    @Published var vocalVolume: Double = 1.0
    @Published var cachedInstrumentalId: String? = nil
    @Published var equalizerPreset: EqualizerPreset = .flat
    @Published var endlessAutoplay: Bool = true
    
    init() {
        setupAudioSession()
        setupRemoteCommands()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.allowBluetooth, .allowAirPlay])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set audio session category: \(error)")
        }
    }
    
    private func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.resume()
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }
        
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.playNext()
            return .success
        }
        
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.playPrevious()
            return .success
        }
        
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let posEvent = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self?.seek(to: posEvent.positionTime)
            return .success
        }
    }
    
    func play(track: Track, fromQueue: [Track] = []) {
        self.currentTrack = track
        self.isLoading = true
        self.lyrics = []
        self.currentLyricIndex = 0
        self.currentTime = 0
        self.duration = Double(track.durationSeconds ?? 0)
        self.cachedArtwork = nil
        self.isTransitioning = false
        
        LibraryStorageManager.shared.addToHistory(track: track)
        
        if !fromQueue.isEmpty {
            self.originalQueue = fromQueue
            if isShuffle {
                var shuffled = fromQueue.filter { $0.id != track.id }
                shuffled.shuffle()
                self.queue = shuffled
            } else {
                if let idx = fromQueue.firstIndex(where: { $0.id == track.id }) {
                    let nextTracks = Array(fromQueue.suffix(from: fromQueue.index(after: idx)))
                    self.queue = nextTracks
                }
            }
        }
        
        // Reset vocal & karaoke
        self.vocalVolume = 1.0
        self.isKaraokeMode = false
        self.cachedInstrumentalId = nil
        
        // Preload Studio Instrumental Track ID in background
        Task {
            let instId = await YouTubeMusicService.shared.fetchInstrumentalTrack(title: track.title, artist: track.artist)
            await MainActor.run {
                self.cachedInstrumentalId = instId
            }
        }
        
        // 1. Fetch lyrics & official studio song duration async
        Task {
            let pkg = await LyricsService.shared.fetchLyrics(
                title: track.title,
                artist: track.artist,
                duration: self.duration > 0 ? self.duration : Double(track.durationSeconds ?? 0)
            )
            await MainActor.run {
                self.lyrics = pkg.lines
                if let officialDur = pkg.officialDuration, officialDur > 30 {
                    self.officialTrackDuration = officialDur
                    // Cut off long video silence: if stream duration exceeds official track by >10s
                    if self.duration > (officialDur + 10) || self.duration == 0 {
                        self.duration = officialDur
                    }
                }
            }
        }
        
        // 2. Resolve Stream URL (with Instant Preload Cache) & Start Native AVPlayer
        Task {
            // Check if URL was already pre-resolved during the previous song
            if let preloadedId = self.preloadedTrackId, preloadedId == track.id, let cachedUrl = self.preloadedStreamUrl {
                await MainActor.run {
                    self.startNativePlayback(url: cachedUrl, track: self.currentTrack ?? track)
                }
                self.preloadNextTrackIfNeeded()
                return
            }
            
            var actualVideoId = track.id
            var resolvedThumb = track.thumbnailUrl
            
            if track.id.hasPrefix("sp:") || track.thumbnailUrl.isEmpty {
                if let found = try? await YouTubeMusicService.shared.search(query: "\(track.title) \(track.artist)"), let first = found.first {
                    actualVideoId = first.id
                    if !first.thumbnailUrl.isEmpty {
                        resolvedThumb = first.thumbnailUrl
                        await MainActor.run {
                            if self.currentTrack?.id == track.id {
                                self.currentTrack = Track(
                                    id: track.id,
                                    title: track.title,
                                    artist: track.artist,
                                    thumbnailUrl: resolvedThumb,
                                    durationSeconds: track.durationSeconds,
                                    isKaraokeMode: track.isKaraokeMode
                                )
                            }
                            LibraryStorageManager.shared.updateTrackThumbnail(trackId: track.id, newThumbnailUrl: resolvedThumb)
                        }
                    }
                }
            }
            
            if let streamUrl = await YouTubeMusicService.shared.resolveStreamURL(videoId: actualVideoId) {
                await MainActor.run {
                    self.startNativePlayback(url: streamUrl, track: self.currentTrack ?? track)
                }
                self.preloadNextTrackIfNeeded()
            } else {
                // Fallback to WebKit bridge if Google limits direct resolution
                await MainActor.run {
                    YouTubeAudioBridge.shared.loadVideo(videoId: actualVideoId)
                }
            }
        }
        
        // Artwork for lockscreen
        let artworkTargetUrl = track.thumbnailUrl
        if let thumbUrl = URL(string: artworkTargetUrl), !artworkTargetUrl.isEmpty {
            Task {
                if let (data, _) = try? await URLSession.shared.data(from: thumbUrl),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        self.cachedArtwork = image
                        self.updateNowPlaying(track: track, elapsed: self.currentTime, duration: self.duration, artwork: image)
                    }
                }
            }
        }
    }
    
    private func startNativePlayback(url: URL, track: Track) {
        // Remove previous observers
        if let observer = timeObserver {
            avPlayer?.removeTimeObserver(observer)
            timeObserver = nil
        }
        if let observer = endObserver {
            NotificationCenter.default.removeObserver(observer)
            endObserver = nil
        }
        
        let asset = AVURLAsset(url: url, options: [
            "AVURLAssetHTTPHeaderFieldsKey": [
                "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 15_7_3) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Safari/605.1.15"
            ]
        ])
        let playerItem = AVPlayerItem(asset: asset)
        playerItem.preferredForwardBufferDuration = 1.0
        
        if self.avPlayer == nil {
            self.avPlayer = AVPlayer(playerItem: playerItem)
            self.avPlayer?.actionAtItemEnd = .none
            self.avPlayer?.automaticallyWaitsToMinimizeStalling = false
        } else {
            self.avPlayer?.replaceCurrentItem(with: playerItem)
            self.avPlayer?.automaticallyWaitsToMinimizeStalling = false
        }
        
        self.avPlayer?.play()
        self.isPlaying = true
        self.isLoading = false
        
        // Periodic time observer for smooth slider scrubbing & lyrics
        let interval = CMTime(seconds: 0.25, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        self.timeObserver = self.avPlayer?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            self.currentTime = time.seconds
            
            if let dur = self.avPlayer?.currentItem?.duration.seconds, !dur.isNaN && dur > 0 {
                if let official = self.officialTrackDuration, official > 30 {
                    self.duration = official
                } else if self.duration == 0 {
                    self.duration = dur
                }
            }
            
            // Auto-advance if we reached the end of the song (cuts off empty outro silence)
            if self.duration > 0 && self.currentTime >= (self.duration - 0.5) && self.isPlaying && !self.isTransitioning {
                self.isTransitioning = true
                self.handleTrackEnded()
                return
            }
            
            self.onTimeUpdated()
        }
        
        // Track finished observer
        self.endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            self?.handleTrackEnded()
        }
        
        self.updateNowPlaying(track: track, elapsed: 0, duration: self.duration, artwork: self.cachedArtwork)
    }
    
    private func preloadNextTrackIfNeeded() {
        var nextTrack: Track? = nil
        if !queue.isEmpty {
            nextTrack = queue.first
        } else if !originalQueue.isEmpty, let cur = currentTrack, let idx = originalQueue.firstIndex(where: { $0.id == cur.id }) {
            let nextIdx = (idx + 1) % originalQueue.count
            nextTrack = originalQueue[nextIdx]
        }
        
        guard let target = nextTrack else { return }
        Task.detached(priority: .background) {
            var actualId = target.id
            if target.id.hasPrefix("sp:") {
                if let found = try? await YouTubeMusicService.shared.search(query: "\(target.title) \(target.artist)"), let first = found.first {
                    actualId = first.id
                }
            }
            if let url = await YouTubeMusicService.shared.resolveStreamURL(videoId: actualId) {
                await MainActor.run {
                    self.preloadedTrackId = target.id
                    self.preloadedStreamUrl = url
                }
            }
        }
    }
    
    func onTimeUpdated() {
        updateCurrentLyricIndex()
        if let track = currentTrack {
            updateNowPlaying(track: track, elapsed: currentTime, duration: duration, artwork: cachedArtwork)
        }
    }
    
    private func updateCurrentLyricIndex() {
        guard !lyrics.isEmpty else { return }
        let adjustedTime = currentTime + lyricsOffset
        for i in (0..<lyrics.count).reversed() {
            if adjustedTime >= lyrics[i].time {
                if currentLyricIndex != i {
                    currentLyricIndex = i
                }
                break
            }
        }
    }
    
    func adjustLyricsOffset(by delta: Double) {
        lyricsOffset += delta
        updateCurrentLyricIndex()
    }
    
    func handleTrackEnded() {
        if sleepTimerOption == .endOfTrack {
            pause()
            setSleepTimer(option: .off)
            return
        }
        
        switch repeatMode {
        case .one:
            seek(to: 0)
            resume()
        case .all:
            if !queue.isEmpty {
                playNext()
            } else if !originalQueue.isEmpty, let first = originalQueue.first {
                play(track: first, fromQueue: originalQueue)
            }
        case .off:
            if !queue.isEmpty {
                playNext()
            } else if endlessAutoplay, let last = currentTrack {
                // Radio mode: automatically fetch recommended tracks
                Task {
                    let related = await YouTubeMusicService.shared.fetchTrending()
                    await MainActor.run {
                        self.queue = related.filter { $0.id != last.id }
                        self.playNext()
                    }
                }
            } else {
                pause()
            }
        }
    }
    
    func setVocalVolume(_ newVol: Double) {
        self.vocalVolume = newVol
        guard let track = currentTrack else { return }
        
        if newVol < 0.4 {
            // Hilangkan vokal -> Beralih ke Studio Instrumental / Minus One
            if !isKaraokeMode {
                isKaraokeMode = true
                if let instId = cachedInstrumentalId {
                    swapToInstrumental(videoId: instId)
                } else {
                    Task {
                        if let instId = await YouTubeMusicService.shared.fetchInstrumentalTrack(title: track.title, artist: track.artist) {
                            await MainActor.run {
                                self.cachedInstrumentalId = instId
                                if self.isKaraokeMode {
                                    self.swapToInstrumental(videoId: instId)
                                }
                            }
                        }
                    }
                }
            }
        } else {
            // Kembalikan vokal penuh asli
            if isKaraokeMode {
                isKaraokeMode = false
                swapToInstrumental(videoId: track.id)
            }
        }
    }
    
    private func swapToInstrumental(videoId: String) {
        let time = self.currentTime
        Task {
            if let streamUrl = await YouTubeMusicService.shared.resolveStreamURL(videoId: videoId) {
                await MainActor.run {
                    if let cur = self.currentTrack {
                        self.startNativePlayback(url: streamUrl, track: cur)
                        self.seek(to: time)
                    }
                }
            } else {
                await MainActor.run {
                    YouTubeAudioBridge.shared.swapToInstrumental(videoId: videoId, atTime: time)
                }
            }
        }
    }
    
    func toggleKaraokeMode() {
        if vocalVolume < 0.4 {
            setVocalVolume(1.0)
        } else {
            setVocalVolume(0.0)
        }
    }
    
    func setEqualizerPreset(_ preset: EqualizerPreset) {
        self.equalizerPreset = preset
    }
    
    func playNext() {
        if !queue.isEmpty {
            let next = queue.removeFirst()
            play(track: next, fromQueue: originalQueue)
            return
        }
        // If queue is exhausted, loop seamlessly through original playlist
        if !originalQueue.isEmpty, let cur = currentTrack, let idx = originalQueue.firstIndex(where: { $0.id == cur.id }) {
            let nextIdx = (idx + 1) % originalQueue.count
            let next = originalQueue[nextIdx]
            play(track: next, fromQueue: originalQueue)
            return
        }
        if let first = originalQueue.first {
            play(track: first, fromQueue: originalQueue)
        }
    }
    
    func playPrevious() {
        if currentTime > 3.0 {
            seek(to: 0)
            resume()
            return
        }
        if !originalQueue.isEmpty, let cur = currentTrack, let idx = originalQueue.firstIndex(where: { $0.id == cur.id }) {
            let prevIdx = idx > 0 ? idx - 1 : originalQueue.count - 1
            let prev = originalQueue[prevIdx]
            play(track: prev, fromQueue: originalQueue)
        } else {
            seek(to: 0)
            resume()
        }
    }
    
    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            resume()
        }
    }
    
    func pause() {
        isPlaying = false
        avPlayer?.pause()
        YouTubeAudioBridge.shared.pause()
        if let track = currentTrack {
            updateNowPlaying(track: track, elapsed: currentTime, duration: duration, artwork: cachedArtwork)
        }
    }
    
    func resume() {
        isPlaying = true
        if avPlayer != nil {
            avPlayer?.play()
        } else {
            YouTubeAudioBridge.shared.play()
        }
        if let track = currentTrack {
            updateNowPlaying(track: track, elapsed: currentTime, duration: duration, artwork: cachedArtwork)
        }
    }
    
    func seek(to seconds: TimeInterval) {
        currentTime = seconds
        if let player = avPlayer {
            let targetTime = CMTime(seconds: seconds, preferredTimescale: 600)
            player.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero)
        } else {
            YouTubeAudioBridge.shared.seek(to: seconds)
        }
        if let track = currentTrack {
            updateNowPlaying(track: track, elapsed: seconds, duration: duration, artwork: cachedArtwork)
        }
    }
    
    func toggleShuffle() {
        isShuffle.toggle()
        if isShuffle {
            queue.shuffle()
        } else {
            if let cur = currentTrack, let idx = originalQueue.firstIndex(where: { $0.id == cur.id }) {
                queue = Array(originalQueue.suffix(from: originalQueue.index(after: idx)))
            }
        }
    }
    
    func cycleRepeatMode() {
        switch repeatMode {
        case .off: repeatMode = .all
        case .all: repeatMode = .one
        case .one: repeatMode = .off
        }
    }
    
    func setPlaybackSpeed(_ speed: Float) {
        self.playbackSpeed = speed
        avPlayer?.rate = speed
        YouTubeAudioBridge.shared.setPlaybackRate(speed)
    }
    
    func setSleepTimer(option: SleepTimerOption) {
        self.sleepTimerOption = option
        sleepTimer?.invalidate()
        sleepTimer = nil
        
        guard let sec = option.seconds, sec > 0 else {
            sleepTimerRemainingSeconds = 0
            return
        }
        
        sleepTimerRemainingSeconds = sec
        sleepTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] t in
            guard let self = self else { return }
            if self.sleepTimerRemainingSeconds > 0 {
                self.sleepTimerRemainingSeconds -= 1
            } else {
                t.invalidate()
                self.sleepTimer = nil
                self.pause()
                self.sleepTimerOption = .off
            }
        }
    }
    
    private func updateNowPlaying(track: Track, elapsed: TimeInterval, duration: TimeInterval, artwork: UIImage? = nil) {
        var info = [String: Any]()
        info[MPMediaItemPropertyTitle] = track.title
        info[MPMediaItemPropertyArtist] = track.artist
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsed
        info[MPMediaItemPropertyPlaybackDuration] = duration
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? Double(playbackSpeed) : 0.0
        
        if let image = artwork {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
