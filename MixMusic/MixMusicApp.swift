import SwiftUI
import AVFoundation

@main
struct MixMusicApp: App {
    init() {
        // Activate background audio playback on iOS startup
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("[MixMusicApp] Failed to set background audio category: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}
