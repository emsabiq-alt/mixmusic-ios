import SwiftUI

struct LibraryView: View {
    @ObservedObject var library = LibraryStorageManager.shared
    @ObservedObject var player = AudioPlayerManager.shared
    @ObservedObject var spotify = SpotifyService.shared
    
    @State private var showCreatePlaylistSheet: Bool = false
    @State private var showImportLinkSheet: Bool = false
    @State private var playlistToRename: Playlist? = nil
    @State private var renamePlaylistTitle: String = ""
    @State private var newPlaylistTitle: String = ""
    @State private var importLinkUrl: String = ""
    @State private var isImporting: Bool = false
    
    private let spotifyGreen = Color(hex: "1DB954")
    
    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Text("Koleksi Kamu")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        Spacer()
                        
                        Menu {
                            Button(action: { showCreatePlaylistSheet = true }) {
                                Label("Buat Playlist Baru", systemImage: "plus")
                            }
                            Button(action: { showImportLinkSheet = true }) {
                                Label("Impor dari Link Spotify/YT", systemImage: "link.badge.plus")
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(spotifyGreen)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    
                    // Spotify Integration Card
                    if spotify.isLoggedIn {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 14) {
                                if let imgUrl = spotify.userProfile?.images?.first?.url, let url = URL(string: imgUrl) {
                                    AsyncImage(url: url) { img in
                                        img.resizable().scaledToFill().frame(width: 46, height: 46).clipShape(Circle())
                                    } placeholder: {
                                        Circle().fill(Color(hex: "333333")).frame(width: 46, height: 46)
                                    }
                                } else {
                                    Image(systemName: "person.crop.circle.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(spotifyGreen)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(spotify.userProfile?.display_name ?? "Akun Spotify")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.white)
                                    Text("Spotify Premium Terhubung")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(spotifyGreen)
                                }
                                
                                Spacer()
                                
                                Button(action: { spotify.logout() }) {
                                    Text("Keluar")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.6))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Color.white.opacity(0.1))
                                        .cornerRadius(8)
                                }
                            }
                            
                            // Spotify Liked Songs shortcut
                            NavigationLink(destination: PlaylistDetailView(title: "Spotify Liked Songs", tracks: spotify.likedTracks)) {
                                HStack(spacing: 12) {
                                    Image(systemName: "heart.circle.fill")
                                        .font(.title3)
                                        .foregroundColor(spotifyGreen)
                                    Text("Lagu Disukai Spotify (\(spotify.likedTracks.count))")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption2)
                                        .foregroundColor(.white.opacity(0.4))
                                }
                                .padding(10)
                                .background(Color.white.opacity(0.06))
                                .cornerRadius(10)
                            }
                        }
                        .padding(14)
                        .background(Color(hex: "1F1F1F"))
                        .cornerRadius(14)
                        .padding(.horizontal, 20)
                    } else {
                        Button(action: { spotify.startLogin() }) {
                            HStack(spacing: 14) {
                                Image(systemName: "waveform.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(spotifyGreen)
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Hubungkan Spotify Premium")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(.white)
                                    Text("Akses seluruh playlist & lagu favoritmu")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white.opacity(0.6))
                                }
                                
                                Spacer()
                                
                                Text("Masuk")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background(spotifyGreen)
                                    .cornerRadius(20)
                            }
                            .padding(14)
                            .background(Color(hex: "1F1F1F"))
                            .cornerRadius(14)
                            .padding(.horizontal, 20)
                        }
                    }
                    
                    // 1. Musik Diunduh (Offline Mode)
                    NavigationLink(destination: PlaylistDetailView(title: "Musik Diunduh (Offline)", tracks: library.downloadedTracks)) {
                        HStack(spacing: 16) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(LinearGradient(colors: [Color(hex: "1DB954"), Color(hex: "191414")], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 58, height: 58)
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Musik Diunduh (Offline)")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                Text("\(library.downloadedTracks.count) Lagu Tersimpan")
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(hex: "B3B3B3"))
                            }
                            
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(Color(hex: "777777"))
                        }
                        .padding(12)
                        .background(Color(hex: "1F1F1F"))
                        .cornerRadius(14)
                        .padding(.horizontal, 20)
                    }
                    
                    // 2. Liked Songs Banner
                    NavigationLink(destination: PlaylistDetailView(title: "Lagu yang Disukai", tracks: library.likedTracks)) {
                        HStack(spacing: 16) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(LinearGradient(colors: [Color(hex: "450AF5"), Color(hex: "8E8EE5")], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 58, height: 58)
                                Image(systemName: "heart.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Lagu yang Disukai")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                Text("\(library.likedTracks.count) Lagu")
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(hex: "B3B3B3"))
                            }
                            
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(Color(hex: "777777"))
                        }
                        .padding(12)
                        .background(Color(hex: "1F1F1F"))
                        .cornerRadius(14)
                        .padding(.horizontal, 20)
                    }
                    
                    // 3. Riwayat Terakhir Diputar
                    NavigationLink(destination: PlaylistDetailView(title: "Baru Saja Diputar", tracks: library.historyTracks)) {
                        HStack(spacing: 16) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(LinearGradient(colors: [Color(hex: "333333"), Color(hex: "1F1F1F")], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 58, height: 58)
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.title2)
                                    .foregroundColor(spotifyGreen)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Baru Saja Diputar")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                Text("\(library.historyTracks.count) Lagu")
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(hex: "B3B3B3"))
                            }
                            
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(Color(hex: "777777"))
                        }
                        .padding(12)
                        .background(Color(hex: "1F1F1F"))
                        .cornerRadius(14)
                        .padding(.horizontal, 20)
                    }
                    
                    // 4. Custom Mixes / Playlists
                    VStack(alignment: .leading, spacing: 12) {
                        Text("PLAYLIST SAYA")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1.4)
                            .foregroundColor(Color(hex: "B3B3B3"))
                            .padding(.horizontal, 20)
                        
                        if library.customPlaylists.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "music.note.list")
                                    .font(.title)
                                    .foregroundColor(.white.opacity(0.3))
                                Text("Belum ada playlist")
                                    .font(.subheadline)
                                    .foregroundColor(Color(hex: "B3B3B3"))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                        } else {
                            ForEach(library.customPlaylists) { playlist in
                                NavigationLink(destination: PlaylistDetailView(title: playlist.title, tracks: playlist.tracks, playlistId: playlist.id)) {
                                    HStack(spacing: 14) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color(hex: "282828"))
                                                .frame(width: 52, height: 52)
                                            Image(systemName: "music.note")
                                                .foregroundColor(spotifyGreen)
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(playlist.title)
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundColor(.white)
                                            Text("\(playlist.trackCount) Lagu")
                                                .font(.caption)
                                                .foregroundColor(Color(hex: "B3B3B3"))
                                        }
                                        Spacer()
                                        
                                        Menu {
                                            Button(action: {
                                                renamePlaylistTitle = playlist.title
                                                playlistToRename = playlist
                                            }) {
                                                Label("Ubah Nama", systemImage: "pencil")
                                            }
                                            Button(role: .destructive, action: {
                                                library.deletePlaylist(playlistId: playlist.id)
                                            }) {
                                                Label("Hapus Playlist", systemImage: "trash")
                                            }
                                        } label: {
                                            Image(systemName: "ellipsis")
                                                .font(.system(size: 14))
                                                .foregroundColor(Color(hex: "777777"))
                                                .frame(width: 32, height: 32)
                                        }
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(Color(hex: "555555"))
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 6)
                                }
                                .contextMenu {
                                    Button(action: {
                                        renamePlaylistTitle = playlist.title
                                        playlistToRename = playlist
                                    }) {
                                        Label("Ubah Nama", systemImage: "pencil")
                                    }
                                    Button(role: .destructive, action: {
                                        library.deletePlaylist(playlistId: playlist.id)
                                    }) {
                                        Label("Hapus Playlist", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                    
                    Spacer(minLength: 80)
                }
            }
            .background(Color(hex: "121212").ignoresSafeArea())
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showCreatePlaylistSheet) {
            NavigationView {
                VStack(spacing: 20) {
                    TextField("Beri nama playlist kamu...", text: $newPlaylistTitle)
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
                        Text("Buat Playlist")
                            .font(.headline)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(spotifyGreen)
                            .cornerRadius(12)
                            .padding(.horizontal, 20)
                    }
                    Spacer()
                }
                .background(Color(hex: "121212").ignoresSafeArea())
                .navigationTitle("Playlist Baru")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Batal") { showCreatePlaylistSheet = false }
                    }
                }
            }
        }
        .sheet(isPresented: $showImportLinkSheet) {
            NavigationView {
                VStack(spacing: 20) {
                    Text("Tempel (Paste) link playlist Spotify atau YouTube:")
                        .font(.subheadline)
                        .foregroundColor(Color(hex: "B3B3B3"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    
                    TextField("https://open.spotify.com/playlist/...", text: $importLinkUrl)
                        .padding(14)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(12)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                    
                    if isImporting {
                        ProgressView("Mengimpor lagu...")
                            .progressViewStyle(CircularProgressViewStyle(tint: spotifyGreen))
                            .foregroundColor(.white)
                    } else {
                        Button(action: {
                            isImporting = true
                            Task {
                                let success = await library.importPlaylistFromLink(link: importLinkUrl)
                                await MainActor.run {
                                    isImporting = false
                                    if success {
                                        importLinkUrl = ""
                                        showImportLinkSheet = false
                                    }
                                }
                            }
                        }) {
                            Text("Impor Playlist")
                                .font(.headline)
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(spotifyGreen)
                                .cornerRadius(12)
                                .padding(.horizontal, 20)
                        }
                    }
                    Spacer()
                }
                .background(Color(hex: "121212").ignoresSafeArea())
                .navigationTitle("Impor Playlist")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Batal") { showImportLinkSheet = false }
                    }
                }
            }
        }
        .sheet(item: $playlistToRename) { p in
            NavigationView {
                VStack(spacing: 20) {
                    TextField("Nama playlist baru...", text: $renamePlaylistTitle)
                        .padding(14)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(12)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                    
                    Button(action: {
                        library.renamePlaylist(playlistId: p.id, newTitle: renamePlaylistTitle)
                        playlistToRename = nil
                    }) {
                        Text("Simpan Perubahan")
                            .font(.headline)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(spotifyGreen)
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
                        Button("Batal") { playlistToRename = nil }
                    }
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { spotify.activeLoginUrl != nil },
            set: { if !$0 { spotify.cancelLogin() } }
        )) {
            if let url = spotify.activeLoginUrl {
                SpotifyLoginSheetView(authUrl: url)
            }
        }
    }
}
