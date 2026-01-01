import SwiftUI

struct AboutView: View {
    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
    
    var body: some View {
        VStack(spacing: 40) {
            Image(systemName: "play.tv.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 200, height: 200)
                .foregroundStyle(.tint)
                .shadow(radius: 10)
            
            VStack(spacing: 16) {
                Text("QvPlayer")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text(String(format: NSLocalizedString("Version %@ (Build %@)", comment: "Version info"), appVersion, buildNumber))
                    .font(.title3)
                    .foregroundColor(.secondary)
                
                Text("Designed for Apple TV")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                if let serverURL = WebServer.shared.serverURL {
                    VStack(spacing: 8) {
                        Text("Manage Playlist via Web Browser:")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text(serverURL)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                }
            }
            
            VStack(spacing: 12) {
                HStack {
                    Text(NSLocalizedString("Privacy Policy:", comment: ""))
                        .foregroundColor(.secondary)
                    Text("https://qvcloud.github.io/QvPlayer/privacy.html")
                        .foregroundColor(.blue)
                }
                
                HStack {
                    Text(NSLocalizedString("Support:", comment: ""))
                        .foregroundColor(.secondary)
                    Text("https://qvcloud.github.io/QvPlayer/support.html")
                        .foregroundColor(.blue)
                }
            }
            .font(.caption)
            
            Spacer()
                .frame(height: 50)
            
            Text("© 2025 Easton. All rights reserved.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.2)) // Subtle background
    }
}

#Preview {
    AboutView()
}
