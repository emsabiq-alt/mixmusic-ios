import SwiftUI

struct LyricsView: View {
    @ObservedObject var player = AudioPlayerManager.shared
    
    var body: some View {
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
                        .padding(.top, 80)
                    } else {
                        ForEach(Array(player.lyrics.enumerated()), id: \.element.id) { index, line in
                            Text(line.text)
                                .font(.system(size: player.currentLyricIndex == index ? 26 : 20, weight: player.currentLyricIndex == index ? .bold : .medium, design: .rounded))
                                .foregroundColor(player.currentLyricIndex == index ? .white : .white.opacity(0.35))
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
                .padding(.vertical, 60)
            }
            .onChange(of: player.currentLyricIndex) { newIndex in
                withAnimation(.easeInOut(duration: 0.4)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
    }
}
