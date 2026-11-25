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
            ZStack {
                HeadlessAudioBridgeView()
                    .frame(width: 320, height: 180)
                MainTabView()
            }
            .preferredColorScheme(.dark)
        }
    }
}
