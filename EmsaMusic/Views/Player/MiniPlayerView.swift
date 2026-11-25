import SwiftUI

struct MiniPlayerView: View {
    @ObservedObject var player = AudioPlayerManager.shared
    @Binding var showFullscreen: Bool
    
    var body: some View {
        if let track = player.currentTrack {
            VStack(spacing: 0) {
                // Micro progress line
                GeometryReader { geo in
                    let progress = player.duration > 0 ? (player.currentTime / player.duration) : 0
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Color.white.opacity(0.1)).frame(height: 2)
                        Rectangle().fill(Color.cyan).frame(width: geo.size.width * CGFloat(progress), height: 2)
                    }
                }
                .frame(height: 2)
                
                HStack(spacing: 12) {
                    AsyncImage(url: URL(string: track.thumbnailUrl)) { img in
                        img.resizable().scaledToFill().frame(width: 44, height: 44).cornerRadius(8)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.2)).frame(width: 44, height: 44)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.title)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Text(track.artist)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    Button(action: { player.togglePlayPause() }) {
                        if player.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
                                .frame(width: 36, height: 36)
                        } else {
                            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                .font(.title3)
                                .foregroundColor(.white)
                                .frame(width: 36, height: 36)
                        }
                    }
                    
                    Button(action: { player.playNext() }) {
                        Image(systemName: "forward.fill")
                            .font(.body)
                            .foregroundColor(.white.opacity(0.7))
                            .frame(width: 32, height: 32)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hex: "14161F").opacity(0.96))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.4), radius: 10, y: 5)
            )
            .padding(.horizontal, 12)
            .contentShape(Rectangle())
            .onTapGesture {
                showFullscreen = true
            }
        }
    }
}
