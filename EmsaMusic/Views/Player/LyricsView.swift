import SwiftUI

struct LyricsView: View {
    @ObservedObject var player = AudioPlayerManager.shared
    
    var body: some View {
        VStack(spacing: 10) {
            // Apple Music Sing & Calibration Toolbar
            HStack(spacing: 12) {
                // Apple Music Sing Vocal Attenuator Slider
                HStack(spacing: 6) {
                    Image(systemName: player.vocalVolume < 0.4 ? "mic.slash.fill" : "mic.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(player.vocalVolume < 0.4 ? Color(hex: "FF2E93") : Color(hex: "1DB954"))
                    
                    Slider(value: Binding(
                        get: { player.vocalVolume },
                        set: { player.setVocalVolume($0) }
                    ), in: 0...1)
                    .accentColor(player.vocalVolume < 0.4 ? Color(hex: "FF2E93") : Color(hex: "1DB954"))
                    .frame(width: 85)
                    
                    Text(player.vocalVolume < 0.4 ? "KARAOKE" : "VOKAL")
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(player.vocalVolume < 0.4 ? Color(hex: "FF2E93") : .white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
                
                Spacer()
                
                // Timing Offset Buttons
                HStack(spacing: 6) {
                    Button(action: { player.adjustLyricsOffset(by: -0.5) }) {
                        Text("-0.5s")
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(8)
                            .foregroundColor(.white)
                    }
                    
                    if player.lyricsOffset != 0.0 {
                        Button(action: { player.lyricsOffset = 0.0; player.adjustLyricsOffset(by: 0) }) {
                            Text("Reset")
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .background(Color(hex: "1DB954").opacity(0.3))
                                .cornerRadius(8)
                                .foregroundColor(Color(hex: "1DB954"))
                        }
                    }
                    
                    Button(action: { player.adjustLyricsOffset(by: 0.5) }) {
                        Text("+0.5s")
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(8)
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            
            // Synced Scrollable Lyrics
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        if player.lyrics.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "quote.bubble")
                                    .font(.system(size: 44))
                                    .foregroundColor(.white.opacity(0.3))
                                Text("Lirik tidak tersedia untuk lagu ini.")
                                    .font(.headline)
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                        } else {
                            ForEach(Array(player.lyrics.enumerated()), id: \.element.id) { index, line in
                                Text(line.text)
                                    .font(.system(size: player.currentLyricIndex == index ? 25 : 19, weight: player.currentLyricIndex == index ? .black : .medium, design: .rounded))
                                    .foregroundColor(player.currentLyricIndex == index ? (player.isKaraokeMode ? Color(hex: "FF2E93") : .white) : .white.opacity(0.32))
                                    .scaleEffect(player.currentLyricIndex == index ? 1.05 : 1.0)
                                    .animation(.spring(response: 0.35, dampingFraction: 0.7), value: player.currentLyricIndex)
                                    .id(index)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        player.seek(to: line.time)
                                    }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 24)
                }
                .onChange(of: player.currentLyricIndex) { newIndex in
                    withAnimation(.easeInOut(duration: 0.35)) {
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                }
            }
        }
    }
}
