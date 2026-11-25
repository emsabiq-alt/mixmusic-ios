import SwiftUI

struct PlaylistDetailView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var player = AudioPlayerManager.shared
    @ObservedObject var library = LibraryStorageManager.shared
    
    let title: String
    let tracks: [Track]
    var playlistId: UUID? = nil
    
    @State private var showRenameDialog: Bool = false
    @State private var renameText: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Header Artwork & Stats
                    VStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 18)
                                .fill(LinearGradient(colors: [.cyan.opacity(0.8), .indigo.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 160, height: 160)
                                .shadow(color: .cyan.opacity(0.3), radius: 15, y: 8)
                            
                            if let first = tracks.first, let url = URL(string: first.thumbnailUrl) {
                                AsyncImage(url: url) { img in
                                    img.resizable().scaledToFill().frame(width: 160, height: 160).cornerRadius(18)
                                } placeholder: {
                                    Image(systemName: "music.note")
                                        .font(.system(size: 50))
                                        .foregroundColor(.white)
                                }
                            } else {
                                Image(systemName: "music.note.list")
                                    .font(.system(size: 50))
                                    .foregroundColor(.white)
                            }
                        }
                        
                        Text(title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("\(tracks.count) Lagu")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)
                    
                    // Action Buttons (Play & Shuffle)
                    if !tracks.isEmpty {
                        HStack(spacing: 14) {
                            Button(action: {
                                if let first = tracks.first {
                                    player.play(track: first, fromQueue: tracks)
                                }
                            }) {
                                HStack {
                                    Image(systemName: "play.fill")
                                    Text("Putar")
                                }
                                .font(.headline)
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.cyan)
                                .cornerRadius(12)
                            }
                            
                            Button(action: {
                                var shuffled = tracks
                                shuffled.shuffle()
                                if let first = shuffled.first {
                                    player.isShuffle = true
                                    player.play(track: first, fromQueue: shuffled)
                                }
                            }) {
                                HStack {
                                    Image(systemName: "shuffle")
                                    Text("Acak")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.white.opacity(0.12))
                                .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                    
                    // Track List
                    VStack(spacing: 6) {
                        ForEach(tracks) { track in
                            HStack(spacing: 14) {
                                AsyncImage(url: URL(string: track.thumbnailUrl)) { img in
                                    img.resizable().scaledToFill().frame(width: 48, height: 48).cornerRadius(8)
                                } placeholder: {
                                    RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.2)).frame(width: 48, height: 48)
                                }
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(track.title)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(player.currentTrack?.id == track.id ? .cyan : .white)
                                        .lineLimit(1)
                                    Text(track.artist)
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                
                                Spacer()
                                
                                if let pId = playlistId {
                                    Button(action: { library.removeTrackFromPlaylist(playlistId: pId, trackId: track.id) }) {
                                        Image(systemName: "minus.circle")
                                            .foregroundColor(.red.opacity(0.7))
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                player.play(track: track, fromQueue: tracks)
                            }
                        }
                    }
                    
                    Spacer(minLength: 80)
                }
            }
        }
        .background(Color(hex: "090A0F").ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let pId = playlistId {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: {
                            renameText = title
                            showRenameDialog = true
                        }) {
                            Label("Ubah Nama", systemImage: "pencil")
                        }
                        Button(role: .destructive, action: {
                            library.deletePlaylist(playlistId: pId)
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Label("Hapus Playlist", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .sheet(isPresented: $showRenameDialog) {
            NavigationView {
                VStack(spacing: 20) {
                    TextField("Nama playlist baru...", text: $renameText)
                        .padding(14)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(12)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                    
                    Button(action: {
                        if let pId = playlistId {
                            library.renamePlaylist(playlistId: pId, newTitle: renameText)
                        }
                        showRenameDialog = false
                    }) {
                        Text("Simpan Perubahan")
                            .font(.headline)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(hex: "1DB954"))
                            .cornerRadius(12)
                            .padding(.horizontal, 20)
                    }
                    Spacer()
                }
                .background(Color(hex: "121212").ignoresSafeArea())
                .navigationTitle("Ubah Nama Playlist")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Batal") { showRenameDialog = false }
                    }
                }
            }
        }
    }
}
