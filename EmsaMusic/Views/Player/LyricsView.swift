import SwiftUI

struct LyricsView: View {
    @ObservedObject var player = AudioPlayerManager.shared
    
    var body: some View {
        VStack(spacing: 8) {
            // Lyrics Offset Fine-Tuner (Spotify/Apple Music feature)
            if !player.lyrics.isEmpty {
                HStack(spacing: 12) {
                    Text("KALIBRASI WAKTU:")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white.opacity(0.4))
                    
                    Button(action: { player.adjustLyricsOffset(by: -0.5) }) {
                        Text("-0.5s")
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.12))
                            .cornerRadius(8)
                            .foregroundColor(.white)
                    }
                    
                    if player.lyricsOffset != 0.0 {
                        Button(action: { player.lyricsOffset = 0.0; player.adjustLyricsOffset(by: 0) }) {
                            Text(String(format: "%+.1fs (Reset)", player.lyricsOffset))
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color(hex: "1DB954").opacity(0.3))
                                .cornerRadius(8)
                                .foregroundColor(Color(hex: "1DB954"))
                        }
                    }
                    
                    Button(action: { player.adjustLyricsOffset(by: 0.5) }) {
                        Text("+0.5s")
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.12))
                            .cornerRadius(8)
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 4)
            }
            
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
                                    .font(.system(size: player.currentLyricIndex == index ? 24 : 19, weight: player.currentLyricIndex == index ? .bold : .medium, design: .rounded))
                                    .foregroundColor(player.currentLyricIndex == index ? .white : .white.opacity(0.32))
                                    .scaleEffect(player.currentLyricIndex == index ? 1.04 : 1.0)
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
                    .padding(.vertical, 30)
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
