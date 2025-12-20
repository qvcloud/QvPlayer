import SwiftUI

struct SettingsView: View {
    @AppStorage("proxyEnabled") private var proxyEnabled = false
    @AppStorage("proxyHost") private var proxyHost = ""
    @AppStorage("proxyPort") private var proxyPort = ""
    @AppStorage("proxyUsername") private var proxyUsername = ""
    @AppStorage("proxyPassword") private var proxyPassword = ""
    
    @AppStorage("webServerEnabled") private var webServerEnabled = true
    
    var body: some View {
        Form {
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
                    .onChange(of: webServerEnabled) { newValue in
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
    }
}
