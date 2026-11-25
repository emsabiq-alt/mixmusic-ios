import SwiftUI

struct MainTabView: View {
    @ObservedObject var player = AudioPlayerManager.shared
    @State private var showFullscreenPlayer: Bool = false
    @State private var selectedTab: Int = 0
    
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                HomeView()
                    .tabItem {
                        Image(systemName: "house.fill")
                        Text("Beranda")
                    }
                    .tag(0)
                
                SearchView()
                    .tabItem {
                        Image(systemName: "magnifyingglass")
                        Text("Cari")
                    }
                    .tag(1)
                
                LibraryView()
                    .tabItem {
                        Image(systemName: "music.note.list")
                        Text("Pustaka")
                    }
                    .tag(2)
                
                SettingsView()
                    .tabItem {
                        Image(systemName: "gearshape.fill")
                        Text("Pengaturan")
                    }
                    .tag(3)
            }
            .accentColor(.cyan)
            
            // Floating Mini Player right above Tab Bar
            if player.currentTrack != nil {
                MiniPlayerView(showFullscreen: $showFullscreenPlayer)
                    .padding(.bottom, 54)
            }
        }
        .sheet(isPresented: $showFullscreenPlayer) {
            NowPlayingView(isPresented: $showFullscreenPlayer)
        }
    }
}
