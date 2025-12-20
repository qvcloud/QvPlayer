import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading) {
                    Text("QvPlayer")
                        .font(.largeTitle)
                        .fontWeight(.heavy)
                        .foregroundColor(.white)
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
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 300, maximum: 500), spacing: 40)], spacing: 40) {
                            ForEach(viewModel.videos) { video in
                                NavigationLink(value: video) {
                                    VideoCard(video: video)
                                }
                                .buttonStyle(.card)
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
                    NavigationLink(destination: AboutView()) {
                        Label("About", systemImage: "info.circle")
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
            ZStack {
                Color.gray.opacity(0.3)
                Image(systemName: "play.tv.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 50, height: 50)
                    .foregroundColor(.white.opacity(0.8))
            }
            .aspectRatio(16/9, contentMode: .fit)
            .cornerRadius(10)
            
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
