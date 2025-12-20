//
//  QvPlayerApp.swift
//  QvPlayer
//
//  Created by easton on 2025/12/20.
//

import SwiftUI

@main
struct QvPlayerApp: App {
    @AppStorage("webServerEnabled") private var webServerEnabled = true
    
    init() {
        UserDefaults.standard.register(defaults: ["webServerEnabled": true])
        
        if UserDefaults.standard.bool(forKey: "webServerEnabled") {
            WebServer.shared.start()
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
