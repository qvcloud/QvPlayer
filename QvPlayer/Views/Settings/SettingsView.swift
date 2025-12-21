import SwiftUI

struct SettingsView: View {
    @AppStorage("proxyEnabled") private var proxyEnabled = false
    @AppStorage("proxyHost") private var proxyHost = ""
    @AppStorage("proxyPort") private var proxyPort = ""
    @AppStorage("proxyUsername") private var proxyUsername = ""
    @AppStorage("proxyPassword") private var proxyPassword = ""
    
    @AppStorage("webServerEnabled") private var webServerEnabled = true
    
    @AppStorage("playerEngine") private var playerEngine = "system"
    
    @AppStorage("selectedLanguage") private var selectedLanguage = "system"
    @AppStorage("showDebugOverlay") private var showDebugOverlay = false
    
    @State private var showRestartAlert = false
    @State private var showClearCacheAlert = false
    @State private var showResetAlert = false
    
    var body: some View {
        Form {
            Section(header: Text("General")) {
                Picker("Player Engine", selection: $playerEngine) {
                    Text("System (AVPlayer)").tag("system")
                    Text("KSPlayer (FFmpeg)").tag("ksplayer")
                }
                
                Picker("Language", selection: $selectedLanguage) {
                    Text("Follow System").tag("system")
                    Text("English").tag("en")
                    Text("简体中文").tag("zh-Hans")
                }
                .onChange(of: selectedLanguage) { _, newValue in
                    if newValue == "system" {
                        UserDefaults.standard.removeObject(forKey: "AppleLanguages")
                    } else {
                        UserDefaults.standard.set([newValue], forKey: "AppleLanguages")
                    }
                    UserDefaults.standard.synchronize()
                    showRestartAlert = true
                }
            }
            
            Section(header: Text("Proxy Settings")) {
                Toggle("Enable Proxy", isOn: $proxyEnabled)
                
                if proxyEnabled {
                    HStack {
                        Text("Host")
                        Spacer()
                        TextField("192.168.1.1", text: $proxyHost)
                    }
                    
                    HStack {
                        Text("Port")
                        Spacer()
                        TextField("8080", text: $proxyPort)
                            #if os(iOS)
                            .keyboardType(.numberPad)
                            #endif
                    }
                    
                    HStack {
                        Text("Username")
                        Spacer()
                        TextField("Optional", text: $proxyUsername)
                    }
                    
                    HStack {
                        Text("Password")
                        Spacer()
                        SecureField("Optional", text: $proxyPassword)
                    }
                }
            }
            
            Section(header: Text("LAN Management")) {
                Toggle("Enable Web Manager", isOn: $webServerEnabled)
                    .onChange(of: webServerEnabled) { _, newValue in
                        if newValue {
                            WebServer.shared.start()
                        } else {
                            WebServer.shared.stop()
                        }
                    }
                
                if webServerEnabled, let url = WebServer.shared.serverURL {
                    HStack {
                        Text("Address")
                        Spacer()
                        Text(url)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section(header: Text("Storage")) {
                Button(role: .destructive) {
                    showClearCacheAlert = true
                } label: {
                    Text("Clear All Cache")
                }
                
                Button(role: .destructive) {
                    showResetAlert = true
                } label: {
                    Text("Reset App Data")
                }
            }
            
            Section(header: Text("Debug")) {
                Toggle("Show Debug Overlay", isOn: $showDebugOverlay)
            }
            
            Section(header: Text("About")) {
                NavigationLink(destination: AboutView()) {
                    Text("About This Software")
                }
                
                HStack {
                    Text("Version")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Settings")
        .alert("Restart Required", isPresented: $showRestartAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please restart the app to apply language changes.")
        }
        .alert("Clear Cache", isPresented: $showClearCacheAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                CacheManager.shared.clearAllCache()
            }
        } message: {
            Text("Are you sure you want to clear all cached videos and thumbnails? This action cannot be undone.")
        }
        .alert("Reset App Data", isPresented: $showResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                PlaylistManager.shared.clearAllData()
            }
        } message: {
            Text("This will delete all playlists, videos, and cached files. The app will return to its initial state. This action cannot be undone.")
        }
    }
}
