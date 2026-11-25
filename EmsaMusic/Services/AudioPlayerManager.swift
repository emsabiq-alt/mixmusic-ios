import Foundation
import AVFoundation
import MediaPlayer
import UIKit

class AudioPlayerManager: ObservableObject {
    static let shared = AudioPlayerManager()
    
    private var sleepTimer: Timer?
    
    @Published var currentTrack: Track?
    @Published var queue: [Track] = []
    @Published var originalQueue: [Track] = []
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
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
        
        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            if self?.isPlaying == true {
                YouTubeAudioBridge.shared.play()
                BackgroundAudioKeeper.shared.start()
            }
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
        
        // 1. Fetch lyrics async with duration targeting
        Task {
            let fetchedLyrics = await LyricsService.shared.fetchLyrics(
                title: track.title,
                artist: track.artist,
                duration: self.duration > 0 ? self.duration : Double(track.durationSeconds ?? 0)
            )
            await MainActor.run {
                self.lyrics = fetchedLyrics
            }
        }
        
        // 2. Play via YouTubeAudioBridge & start background keeper
        BackgroundAudioKeeper.shared.start()
        YouTubeAudioBridge.shared.loadVideo(videoId: track.id)
        updateNowPlaying(track: track, elapsed: 0, duration: duration)
        
        // Artwork for lockscreen
        if let thumbUrl = URL(string: track.thumbnailUrl) {
            Task {
                if let (data, _) = try? await URLSession.shared.data(from: thumbUrl),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        self.updateNowPlaying(track: track, elapsed: self.currentTime, duration: self.duration, artwork: image)
                    }
                }
            }
        }
    }
    
    func onTimeUpdated() {
        updateCurrentLyricIndex()
        if let track = currentTrack {
            updateNowPlaying(track: track, elapsed: currentTime, duration: duration)
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
                    YouTubeAudioBridge.shared.swapToInstrumental(videoId: instId, atTime: currentTime)
                } else {
                    Task {
                        if let instId = await YouTubeMusicService.shared.fetchInstrumentalTrack(title: track.title, artist: track.artist) {
                            await MainActor.run {
                                self.cachedInstrumentalId = instId
                                if self.isKaraokeMode {
                                    YouTubeAudioBridge.shared.swapToInstrumental(videoId: instId, atTime: self.currentTime)
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
                YouTubeAudioBridge.shared.swapToInstrumental(videoId: track.id, atTime: currentTime)
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
        guard !queue.isEmpty else { return }
        let next = queue.removeFirst()
        play(track: next, fromQueue: originalQueue)
    }
    
    func playPrevious() {
        if currentTime > 3.0 {
            seek(to: 0)
            resume()
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
        YouTubeAudioBridge.shared.pause()
        BackgroundAudioKeeper.shared.pause()
        isPlaying = false
        if let track = currentTrack {
            updateNowPlaying(track: track, elapsed: currentTime, duration: duration)
        }
    }
    
    func resume() {
        BackgroundAudioKeeper.shared.start()
        YouTubeAudioBridge.shared.play()
        isPlaying = true
        if let track = currentTrack {
            updateNowPlaying(track: track, elapsed: currentTime, duration: duration)
        }
    }
    
    func seek(to seconds: TimeInterval) {
        YouTubeAudioBridge.shared.seek(to: seconds)
        currentTime = seconds
        if let track = currentTrack {
            updateNowPlaying(track: track, elapsed: seconds, duration: duration)
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

class BackgroundAudioKeeper {
    static let shared = BackgroundAudioKeeper()
    private var silentPlayer: AVAudioPlayer?
    
    func start() {
        if silentPlayer != nil {
            silentPlayer?.play()
            return
        }
        
        do {
            let wavData = generateSilentWav()
            silentPlayer = try AVAudioPlayer(data: wavData)
            silentPlayer?.numberOfLoops = -1
            silentPlayer?.volume = 0.001
            silentPlayer?.prepareToPlay()
            silentPlayer?.play()
        } catch {
            print("[BackgroundAudioKeeper] Error: \(error)")
        }
    }
    
    func pause() {
        silentPlayer?.pause()
    }
    
    private func generateSilentWav() -> Data {
        let sampleRate: Int32 = 44100
        let channels: Int16 = 1
        let bitsPerSample: Int16 = 16
        let byteRate = sampleRate * Int32(channels) * Int32(bitsPerSample / 8)
        let blockAlign = channels * (bitsPerSample / 8)
        let dataSize: Int32 = sampleRate * 2
        let chunkSize = 36 + dataSize
        
        var data = Data()
        data.append(contentsOf: [0x52, 0x49, 0x46, 0x46]) // "RIFF"
        data.append(withUnsafeBytes(of: chunkSize.littleEndian) { Data($0) })
        data.append(contentsOf: [0x57, 0x41, 0x56, 0x45]) // "WAVE"
        data.append(contentsOf: [0x66, 0x6D, 0x74, 0x20]) // "fmt "
        let sub1: Int32 = 16
        data.append(withUnsafeBytes(of: sub1.littleEndian) { Data($0) })
        let fmt: Int16 = 1
        data.append(withUnsafeBytes(of: fmt.littleEndian) { Data($0) })
        data.append(withUnsafeBytes(of: channels.littleEndian) { Data($0) })
        data.append(withUnsafeBytes(of: sampleRate.littleEndian) { Data($0) })
        data.append(withUnsafeBytes(of: byteRate.littleEndian) { Data($0) })
        data.append(withUnsafeBytes(of: blockAlign.littleEndian) { Data($0) })
        data.append(withUnsafeBytes(of: bitsPerSample.littleEndian) { Data($0) })
        data.append(contentsOf: [0x64, 0x61, 0x74, 0x61]) // "data"
        data.append(withUnsafeBytes(of: dataSize.littleEndian) { Data($0) })
        data.append(Data(count: Int(dataSize)))
        return data
    }
}
