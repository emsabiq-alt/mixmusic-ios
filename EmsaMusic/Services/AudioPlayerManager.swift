import Foundation
import AVFoundation
import MediaPlayer
import UIKit

class AudioPlayerManager: ObservableObject {
    static let shared = AudioPlayerManager()
    
    private var player: AVPlayer?
    private var timeObserverToken: Any?
    private var sleepTimer: Timer?
    
    @Published var currentTrack: Track?
    @Published var queue: [Track] = []
    @Published var originalQueue: [Track] = []
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var lyrics: [LyricLine] = []
    @Published var currentLyricIndex: Int = 0
    @Published var isLoading: Bool = false
    
    @Published var isShuffle: Bool = false
    @Published var repeatMode: RepeatMode = .off
    @Published var playbackSpeed: Float = 1.0
    @Published var sleepTimerOption: SleepTimerOption = .off
    @Published var sleepTimerRemainingSeconds: TimeInterval = 0
    
    init() {
        setupAudioSession()
        setupRemoteCommands()
        setupPlayerEndObserver()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set audio session category: \(error)")
        }
    }
    
    private func setupPlayerEndObserver() {
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleTrackEnded()
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
    
    // Play track & set up queue
    func play(track: Track, fromQueue: [Track] = []) {
        self.currentTrack = track
        self.isLoading = true
        self.lyrics = []
        self.currentLyricIndex = 0
        
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
        
        Task {
            // 1. Fetch lyrics
            let fetchedLyrics = await LyricsService.shared.fetchLyrics(title: track.title, artist: track.artist)
            await MainActor.run {
                self.lyrics = fetchedLyrics
            }
            
            // 2. Resolve stream URL
            do {
                if let streamUrl = try await YouTubeMusicService.shared.resolveStreamURL(videoId: track.id) {
                    await MainActor.run {
                        self.startPlayback(url: streamUrl, track: track)
                    }
                } else {
                    await MainActor.run {
                        self.isLoading = false
                    }
                }
            } catch {
                print("Stream resolve failed: \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
    
    private func startPlayback(url: URL, track: Track) {
        let item = AVPlayerItem(url: url)
        if player == nil {
            player = AVPlayer(playerItem: item)
        } else {
            player?.replaceCurrentItem(with: item)
        }
        
        player?.rate = playbackSpeed
        self.isPlaying = true
        self.isLoading = false
        
        setupTimeObserver()
        updateNowPlaying(track: track, elapsed: 0, duration: 0)
        
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
    
    private func setupTimeObserver() {
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        
        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
        timeObserverToken = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            self.currentTime = time.seconds
            
            if let currentItem = self.player?.currentItem {
                let d = currentItem.duration.seconds
                if !d.isNaN && d > 0 {
                    self.duration = d
                }
            }
            self.updateCurrentLyricIndex()
        }
    }
    
    private func updateCurrentLyricIndex() {
        guard !lyrics.isEmpty else { return }
        for i in (0..<lyrics.count).reversed() {
            if currentTime >= lyrics[i].time {
                if currentLyricIndex != i {
                    currentLyricIndex = i
                }
                break
            }
        }
    }
    
    private func handleTrackEnded() {
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
            } else {
                pause()
            }
        }
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
            // Restart current track or previous in queue
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
        player?.pause()
        isPlaying = false
        if let track = currentTrack {
            updateNowPlaying(track: track, elapsed: currentTime, duration: duration)
        }
    }
    
    func resume() {
        player?.rate = playbackSpeed
        isPlaying = true
        if let track = currentTrack {
            updateNowPlaying(track: track, elapsed: currentTime, duration: duration)
        }
    }
    
    func seek(to seconds: TimeInterval) {
        let cmTime = CMTime(seconds: seconds, preferredTimescale: 600)
        player?.seek(to: cmTime)
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
        if isPlaying {
            player?.rate = speed
        }
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
