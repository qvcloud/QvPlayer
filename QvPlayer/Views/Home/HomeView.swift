import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    
    var body: some View {
        NavigationStack {
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
        }
    }
}

struct VideoCard: View {
    let video: Video
    
    var body: some View {
        VStack(alignment: .leading) {
            VideoThumbnailView(url: video.url)
                .aspectRatio(16/9, contentMode: .fit)
                .cornerRadius(10)
                .clipped()
            
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
