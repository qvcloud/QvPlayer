import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @State private var navigationPath = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(alignment: .leading) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("QvPlayer")
                            .font(.largeTitle)
                            .fontWeight(.heavy)
                            .foregroundColor(.white)
                        
                        Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0")")
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.leading)
                    .padding(.top)
                    
                    if viewModel.isLoading {
                        HStack {
                            Spacer()
                            ProgressView("Loading Channels...")
                                .progressViewStyle(.circular)
                                .tint(.white)
                            Spacer()
                        }
                        .padding(.top, 100)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 300, maximum: 500), spacing: 40)], spacing: 40, pinnedViews: [.sectionHeaders]) {
                            ForEach(viewModel.videoGroups) { group in
                                Section(header: 
                                    HStack {
                                        Text(group.name)
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .padding(.vertical, 10)
                                            .padding(.leading, 20) // Add some padding to align with title
                                        Spacer()
                                    }
                                    .background(Color.black) // Solid background for sticky header
                                ) {
                                    ForEach(group.videos) { video in
                                        NavigationLink(value: video) {
                                            VideoCard(video: video)
                                        }
                                        .buttonStyle(.card)
                                        .contextMenu {
                                            if video.cachedURL == nil {
                                                Button {
                                                    Task {
                                                        try? await CacheManager.shared.cacheNetworkVideo(url: video.url)
                                                        NotificationCenter.default.post(name: .playlistDidUpdate, object: nil)
                                                    }
                                                } label: {
                                                    Label("Cache Locally", systemImage: "arrow.down.circle")
                                                }
                                            } else {
                                                Button(role: .destructive) {
                                                    CacheManager.shared.removeCachedVideo(url: video.url)
                                                    NotificationCenter.default.post(name: .playlistDidUpdate, object: nil)
                                                } label: {
                                                    Label("Remove Cache", systemImage: "trash")
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationDestination(for: Video.self) { video in
                PlayerView(video: video)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: SettingsView()) {
                        Label("Settings", systemImage: "gear")
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .commandPlayVideo)) { notification in
                if let index = notification.userInfo?["index"] as? Int {
                    let videos = PlaylistManager.shared.getPlaylistVideos()
                    if index >= 0 && index < videos.count {
                        let video = videos[index]
                        navigationPath = NavigationPath()
                        navigationPath.append(video)
                    }
                }
            }
        }
    }
}

struct VideoCard: View {
    let video: Video
    
    var body: some View {
        VStack(alignment: .leading) {
            ZStack(alignment: .topTrailing) {
                VideoThumbnailView(url: video.url)
                    .aspectRatio(16/9, contentMode: .fit)
                    .cornerRadius(10)
                    .clipped()
                
                if video.cachedURL != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .padding(6)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Circle())
                        .padding(6)
                }
            }
            
            Text(video.title)
                .font(.headline)
                .lineLimit(1)
            
            if let description = video.description {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
    }
}
