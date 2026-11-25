import SwiftUI
import AVFoundation

@main
struct EmsaMusicApp: App {
    init() {
        // Activate background audio playback on iOS startup
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("[EmsaMusicApp] Failed to set background audio category: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                MainTabView()
                HeadlessAudioBridgeView()
                    .frame(width: 1, height: 1)
                    .opacity(0.01)
                    .allowsHitTesting(false)
            }
            .preferredColorScheme(.dark)
        }
    }
}
