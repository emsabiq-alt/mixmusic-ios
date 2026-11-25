import SwiftUI

struct MiniPlayerView: View {
    @ObservedObject var player = AudioPlayerManager.shared
    @ObservedObject var library = LibraryStorageManager.shared
    @Binding var showFullscreen: Bool
    
    private let spotifyGreen = Color(hex: "1DB954")
    private let miniPlayerBg = Color(hex: "242424")
    
    var body: some View {
        if let track = player.currentTrack {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    // Small Square Artwork
                    AsyncImage(url: URL(string: track.thumbnailUrl)) { img in
                        img.resizable().scaledToFill().frame(width: 42, height: 42).cornerRadius(6)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 6).fill(Color(hex: "333333")).frame(width: 42, height: 42)
                    }
                    
                    // Track Title & Artist
                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.title)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Text(track.artist)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color(hex: "B3B3B3"))
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Heart Icon
                    Button(action: { library.toggleLike(track: track) }) {
                        Image(systemName: library.isLiked(track: track) ? "heart.fill" : "heart")
                            .font(.system(size: 18))
                            .foregroundColor(library.isLiked(track: track) ? spotifyGreen : Color(hex: "B3B3B3"))
                            .frame(width: 32, height: 32)
                    }
                    
                    // Play/Pause Button
                    Button(action: { player.togglePlayPause() }) {
                        if player.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(width: 36, height: 36)
                        } else {
                            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                                .frame(width: 36, height: 36)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                
                // Spotify Micro Progress Bar at the very bottom edge of the pill
                GeometryReader { geo in
                    let progress = player.duration > 0 ? (player.currentTime / player.duration) : 0
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Color.white.opacity(0.12)).frame(height: 2)
                        Rectangle().fill(spotifyGreen).frame(width: geo.size.width * CGFloat(progress), height: 2)
                    }
                }
                .frame(height: 2)
            }
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(miniPlayerBg.opacity(0.98))
                    .shadow(color: .black.opacity(0.5), radius: 10, y: 4)
            )
            .cornerRadius(8)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
            .onTapGesture {
                showFullscreen = true
            }
        }
    }
}
