import SwiftUI

struct SettingsView: View {
    @AppStorage("proxyEnabled") private var proxyEnabled = false
    @AppStorage("proxyHost") private var proxyHost = ""
    @AppStorage("proxyPort") private var proxyPort = ""
    @AppStorage("proxyUsername") private var proxyUsername = ""
    @AppStorage("proxyPassword") private var proxyPassword = ""
    
    @AppStorage("webServerEnabled") private var webServerEnabled = true
    @AppStorage("webServerPort") private var webServerPort = AppConstants.defaultWebServerPort
    
    @AppStorage("playerEngine") private var playerEngine = AppConstants.defaultPlayerEngine
    
    @AppStorage("selectedLanguage") private var selectedLanguage = "system"
    @AppStorage("showDebugOverlay") private var showDebugOverlay = false
    @AppStorage("autoClearCacheDays") private var autoClearCacheDays = 0
    
    @State private var showRestartAlert = false
    @State private var showClearCacheAlert = false
    @State private var showResetAlert = false
    @State private var cacheSizeString = "..."
    
    var body: some View {
        Form {
            Section(header: Text("General")) {
                Picker("Player Engine", selection: $playerEngine) {
                    Text("System (AVPlayer)").tag("system")
                    Text("KSPlayer (FFmpeg)").tag("ksplayer")
                }
                
                NavigationLink(destination: UserAgentSettingsView()) {
                    HStack {
                        Text("User Agent")
                        Spacer()
                        Text({
                            let ua = DatabaseManager.shared.getConfig(key: "user_agent") ?? ""
                            return ua.isEmpty || ua == AppConstants.defaultUserAgent ? "Default" : "Custom"
                        }())
                            .foregroundColor(.secondary)
                    }
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
                
                if webServerEnabled {
                    HStack {
                        Text("Port")
                        Spacer()
                        TextField("\(AppConstants.defaultWebServerPort)", value: $webServerPort, format: .number.grouping(.never))
                            .onChange(of: webServerPort) { _, _ in
                                WebServer.shared.stop()
                                WebServer.shared.start()
                            }
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
                HStack {
                    Text("Cache Size")
                    Spacer()
                    Text(cacheSizeString)
                        .foregroundStyle(.secondary)
                }
                
                Picker("Auto Clear Cache", selection: $autoClearCacheDays) {
                    Text("Never").tag(0)
                    Text("1 Day").tag(1)
                    Text("3 Days").tag(3)
                    Text("7 Days").tag(7)
                    Text("15 Days").tag(15)
                    Text("30 Days").tag(30)
                }
                
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
                updateCacheSize()
            }
        } message: {
            Text("Are you sure you want to clear all cached videos and thumbnails? This action cannot be undone.")
        }
        .alert("Reset App Data", isPresented: $showResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                MediaManager.shared.clearAllData()
                updateCacheSize()
            }
        } message: {
            Text("This will delete all playlists, videos, and cached files. The app will return to its initial state. This action cannot be undone.")
        }
        .onAppear {
            updateCacheSize()
        }
    }
    
    private func updateCacheSize() {
        Task.detached {
            let size = CacheManager.shared.calculateCacheSize()
            await MainActor.run {
                cacheSizeString = CacheManager.shared.formatSize(size)
            }
        }
    }
}

struct UserAgentSettingsView: View {
    @State private var userAgents: [DatabaseManager.UserAgentItem] = []
    @State private var currentUserAgent: String = ""
    @State private var showAddSheet = false
    @State private var newName = ""
    @State private var newValue = ""
    
    var body: some View {
        Form {
            Section(header: Text("Current User Agent")) {
                Text(currentUserAgent.isEmpty ? "Default (Empty)" : currentUserAgent)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section(header: Text("Presets")) {
                List {
                    ForEach(userAgents, id: \.name) { item in
                        Button(action: {
                            DatabaseManager.shared.setConfig(key: "user_agent", value: item.value)
                            currentUserAgent = item.value
                        }) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(item.name)
                                        .foregroundColor(.primary)
                                    if !item.value.isEmpty {
                                        Text(item.value)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                Spacer()
                                if item.value == currentUserAgent {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                    .onDelete(perform: deleteUserAgent)
                }
            }
            
            Section {
                Button("Add Custom User Agent") {
                    showAddSheet = true
                }
            }
        }
        .navigationTitle("User Agent")
        .onAppear(perform: loadData)
        .sheet(isPresented: $showAddSheet) {
            NavigationView {
                Form {
                    Section(header: Text("New User Agent")) {
                        TextField("Name (e.g. My Browser)", text: $newName)
                        TextField("User Agent String", text: $newValue)
                    }
                }
                .navigationTitle("Add User Agent")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showAddSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            if !newName.isEmpty && !newValue.isEmpty {
                                DatabaseManager.shared.addCustomUserAgent(name: newName, value: newValue)
                                loadData()
                                showAddSheet = false
                                newName = ""
                                newValue = ""
                            }
                        }
                        .disabled(newName.isEmpty || newValue.isEmpty)
                    }
                }
            }
        }
    }
    
    private func loadData() {
        userAgents = DatabaseManager.shared.getAllUserAgents()
        currentUserAgent = DatabaseManager.shared.getConfig(key: "user_agent") ?? ""
    }
    
    private func deleteUserAgent(at offsets: IndexSet) {
        offsets.forEach { index in
            let item = userAgents[index]
            if !item.isSystem {
                DatabaseManager.shared.removeCustomUserAgent(name: item.name)
            }
        }
        loadData()
    }
}
