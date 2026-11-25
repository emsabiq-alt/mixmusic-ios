import SwiftUI
import AVFoundation

@main
struct EmsaMusicApp: App {
    init() {
        // Activate background audio playback on iOS startup
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("[EmsaMusicApp] Failed to set background audio category: \(error)")
        }
        
        // Pre-warm YouTube session cache for instant zero-lag playback
        YouTubeMusicService.shared.prewarmVisitorData()
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                MainTabView()
                HeadlessAudioBridgeView()
                    .frame(width: 2, height: 2)
                    .opacity(0.01)
                    .allowsHitTesting(false)
            }
            .preferredColorScheme(.dark)
        }
    }
}
