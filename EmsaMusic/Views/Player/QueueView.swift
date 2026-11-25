import SwiftUI

struct QueueView: View {
    @ObservedObject var player = AudioPlayerManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("ANTREAN BERIKUTNYA")
                .font(.caption)
                .fontWeight(.bold)
                .tracking(1.5)
                .foregroundColor(.white.opacity(0.6))
                .padding(.horizontal, 24)
                .padding(.top, 24)
            
            if player.queue.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.3))
                    Text("Antrean kosong")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.7))
                    Text("Lagu berikutnya akan diputar otomatis sesuai radio artis.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.4))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(player.queue) { track in
                        HStack(spacing: 12) {
                            AsyncImage(url: URL(string: track.thumbnailUrl)) { img in
                                img.resizable().scaledToFill().frame(width: 44, height: 44).cornerRadius(6)
                            } placeholder: {
                                RoundedRectangle(cornerRadius: 6).fill(Color.gray.opacity(0.2)).frame(width: 44, height: 44)
                            }
                            
                            VStack(alignment: .leading, spacing: 3) {
                                Text(track.title)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                Text(track.artist)
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            player.play(track: track, fromQueue: player.originalQueue)
                        }
                        .listRowBackground(Color.clear)
                    }
                    .onDelete { indexSet in
                        player.queue.remove(atOffsets: indexSet)
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
    }
}
