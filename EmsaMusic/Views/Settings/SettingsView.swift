import SwiftUI

struct SettingsView: View {
    @ObservedObject var player = AudioPlayerManager.shared
    @State private var cacheCleared: Bool = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Pemutaran Audio")) {
                    Picker("Kecepatan Putar", selection: Binding(
                        get: { player.playbackSpeed },
                        set: { player.setPlaybackSpeed($0) }
                    )) {
                        Text("0.75x").tag(Float(0.75))
                        Text("1.0x (Normal)").tag(Float(1.0))
                        Text("1.25x").tag(Float(1.25))
                        Text("1.5x").tag(Float(1.5))
                        Text("2.0x").tag(Float(2.0))
                    }
                    
                    Picker("Sleep Timer (Mati Otomatis)", selection: Binding(
                        get: { player.sleepTimerOption },
                        set: { player.setSleepTimer(option: $0) }
                    )) {
                        ForEach(SleepTimerOption.allCases) { opt in
                            Text(opt.rawValue).tag(opt)
                        }
                    }
                }
                
                Section(header: Text("Penyimpanan & Cache")) {
                    Button(action: {
                        URLCache.shared.removeAllCachedResponses()
                        cacheCleared = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            cacheCleared = false
                        }
                    }) {
                        HStack {
                            Text("Bersihkan Cache Audio & Gambar")
                                .foregroundColor(.white)
                            Spacer()
                            if cacheCleared {
                                Text("Selesai ✅")
                                    .font(.caption)
                                    .foregroundColor(.cyan)
                            }
                        }
                    }
                }
                
                Section(header: Text("Tentang Aplikasi")) {
                    HStack {
                        Text("Nama Aplikasi")
                        Spacer()
                        Text("EmsaMusic")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Versi")
                        Spacer()
                        Text("1.0.0 (Build 1)")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Sumber Audio")
                        Spacer()
                        Text("YouTube Music & Spotify (Ad-Free)")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Penyedia Lirik")
                        Spacer()
                        Text("LRCLIB Synced Lyrics")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Pengembang")
                        Spacer()
                        Text("EmsaPro")
                            .foregroundColor(.cyan)
                    }
                }
            }
            .navigationTitle("Pengaturan")
        }
    }
}
