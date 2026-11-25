import SwiftUI
import AVFoundation

@main
struct EmsaMusicApp: App {
    @Environment(\.scenePhase) var scenePhase
    
    init() {
        // Activate background audio playback on iOS startup
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.allowBluetooth, .allowAirPlay])
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
                    .frame(width: 320, height: 180)
                    .offset(x: -2000, y: -2000)
                    .allowsHitTesting(false)
            }
            .preferredColorScheme(.dark)
        }
        .onChange(of: scenePhase) { phase in
            if phase == .background {
                if AudioPlayerManager.shared.isPlaying {
                    BackgroundAudioKeeper.shared.start()
                }
            }
        }
    }
}
