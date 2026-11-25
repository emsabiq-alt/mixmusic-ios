import SwiftUI

struct LibraryView: View {
    @ObservedObject var library = LibraryStorageManager.shared
    @ObservedObject var player = AudioPlayerManager.shared
    
    @State private var showCreatePlaylistSheet: Bool = false
    @State private var newPlaylistTitle: String = ""
    
    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        Text("Pustaka Saya")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        Spacer()
                        Button(action: { showCreatePlaylistSheet = true }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(.cyan)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    
                    // Liked Songs Banner
                    NavigationLink(destination: PlaylistDetailView(title: "Lagu yang Disukai", tracks: library.likedTracks)) {
                        HStack(spacing: 16) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 64, height: 64)
                                Image(systemName: "heart.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Lagu yang Disukai")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text("\(library.likedTracks.count) Lagu")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(14)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(18)
                        .padding(.horizontal, 20)
                    }
                    
                    // Riwayat Terakhir Diputar
                    NavigationLink(destination: PlaylistDetailView(title: "Baru Saja Diputar", tracks: library.historyTracks)) {
                        HStack(spacing: 16) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(LinearGradient(colors: [.cyan, .teal], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 64, height: 64)
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.title2)
                                    .foregroundColor(.white)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Baru Saja Diputar")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text("\(library.historyTracks.count) Lagu")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(14)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(18)
                        .padding(.horizontal, 20)
                    }
                    
                    // Custom Mixes / Playlists
                    VStack(alignment: .leading, spacing: 12) {
                        Text("DAFTAR PUTAR SAYA")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1.5)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                        
                        if library.customPlaylists.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "music.note.list")
                                    .font(.title)
                                    .foregroundColor(.white.opacity(0.3))
                                Text("Belum ada daftar putar")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                        } else {
                            ForEach(library.customPlaylists) { playlist in
                                NavigationLink(destination: PlaylistDetailView(title: playlist.title, tracks: playlist.tracks, playlistId: playlist.id)) {
                                    HStack(spacing: 14) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color.white.opacity(0.08))
                                                .frame(width: 52, height: 52)
                                            Image(systemName: "music.note")
                                                .foregroundColor(.cyan)
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(playlist.title)
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundColor(.white)
                                            Text("\(playlist.trackCount) Lagu")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 6)
                                }
                            }
                        }
                    }
                    
                    Spacer(minLength: 80)
                }
            }
            .background(Color(hex: "090A0F").ignoresSafeArea())
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showCreatePlaylistSheet) {
            NavigationView {
                VStack(spacing: 20) {
                    TextField("Nama Daftar Putar Baru...", text: $newPlaylistTitle)
                        .padding(14)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(12)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                    
                    Button(action: {
                        if !newPlaylistTitle.trimmingCharacters(in: .whitespaces).isEmpty {
                            library.createPlaylist(title: newPlaylistTitle)
                            newPlaylistTitle = ""
                            showCreatePlaylistSheet = false
                        }
                    }) {
                        Text("Buat Daftar Putar")
                            .font(.headline)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.cyan)
                            .cornerRadius(12)
                            .padding(.horizontal, 20)
                    }
                    Spacer()
                }
                .background(Color(hex: "0D0D12").ignoresSafeArea())
                .navigationTitle("Daftar Putar Baru")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Batal") { showCreatePlaylistSheet = false }
                    }
                }
            }
        }
    }
}
