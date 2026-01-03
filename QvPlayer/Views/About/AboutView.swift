import SwiftUI

struct AboutView: View {
    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
    
    var body: some View {
        VStack(spacing: 60) {
            Spacer()
            
            VStack(spacing: 30) {
                Image(systemName: "play.tv.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 240, height: 240)
                    .foregroundStyle(.tint)
                    .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                
                VStack(spacing: 12) {
                    Text("QvPlayer")
                        .font(.system(size: 80, weight: .black, design: .rounded))
                        .foregroundStyle(.primary)
                    
                    Text(String(format: NSLocalizedString("Version %@ (Build %@)", comment: "Version info"), appVersion, buildNumber))
                        .font(.system(size: 32, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            
            VStack(spacing: 40) {
                if let serverURL = WebServer.shared.serverURL {
                    VStack(spacing: 12) {
                        Text(NSLocalizedString("Manage Playlist via Web Browser:", comment: ""))
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(.secondary)
                        Text(serverURL)
                            .font(.system(size: 48, weight: .bold, design: .monospaced))
                            .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 60)
                    .padding(.vertical, 30)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                }
                
                VStack(spacing: 16) {
                    LinkItem(label: NSLocalizedString("Privacy Policy:", comment: ""), url: "https://qvcloud.github.io/QvPlayer/privacy.html")
                    LinkItem(label: NSLocalizedString("Support:", comment: ""), url: "https://qvcloud.github.io/QvPlayer/support.html")
                }
            }
            
            Spacer()
            
            Text("© 2026 qvcloud. All rights reserved.")
                .font(.system(size: 20))
                .foregroundColor(.secondary.opacity(0.6))
                .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ZStack {
                Color.black
                LinearGradient(colors: [.blue.opacity(0.15), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
            .ignoresSafeArea()
        )
    }
}

struct LinkItem: View {
    let label: String
    let url: String
    @Environment(\.isFocused) var isFocused
    
    var body: some View {
        Button(action: {
            // Links are usually just for display on tvOS, but we can make them focusable
        }) {
            HStack(spacing: 10) {
                Text(label)
                    .foregroundColor(.secondary)
                Text(url)
                    .foregroundColor(.blue)
            }
            .font(.system(size: 24))
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(isFocused ? Color.white.opacity(0.1) : Color.clear)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AboutView()
}
