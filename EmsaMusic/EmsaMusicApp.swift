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
    }
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .preferredColorScheme(.dark)
                .onAppear {
                    YouTubeAudioBridge.shared.attachToRootWindow()
                }
        }
    }
}
