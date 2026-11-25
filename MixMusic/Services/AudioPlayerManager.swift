import Foundation
import AVFoundation
import MediaPlayer
import UIKit

class AudioPlayerManager: ObservableObject {
    static let shared = AudioPlayerManager()
    
    private var player: AVPlayer?
    private var timeObserverToken: Any?
    
    @Published var currentTrack: Track?
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var lyrics: [LyricLine] = []
    @Published var currentLyricIndex: Int = 0
    @Published var isLoading: Bool = false
    
    init() {
        setupAudioSession()
        setupRemoteCommands()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to activate background audio session: \(error)")
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
        
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let posEvent = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self?.seek(to: posEvent.positionTime)
            return .success
        }
    }
    
    func play(track: Track) {
        self.currentTrack = track
        self.isLoading = true
        self.lyrics = []
        self.currentLyricIndex = 0
        
        Task {
            // 1. Fetch lyrics in background
            let fetchedLyrics = await LyricsService.shared.fetchLyrics(title: track.title, artist: track.artist)
            await MainActor.run {
                self.lyrics = fetchedLyrics
            }
            
            // 2. Resolve stream URL
            do {
                if let streamUrl = try await YouTubeService.shared.resolveStreamURL(videoId: track.id) {
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
        
        player?.play()
        self.isPlaying = true
        self.isLoading = false
        
        setupTimeObserver()
        updateNowPlaying(track: track, elapsed: 0, duration: 0)
        
        // Fetch artwork async for lockscreen
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
            
            // Update synced lyrics index
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
        player?.play()
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
    
    private func updateNowPlaying(track: Track, elapsed: TimeInterval, duration: TimeInterval, artwork: UIImage? = nil) {
        var info = [String: Any]()
        info[MPMediaItemPropertyTitle] = track.title
        info[MPMediaItemPropertyArtist] = track.artist
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsed
        info[MPMediaItemPropertyPlaybackDuration] = duration
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        
        if let image = artwork {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
