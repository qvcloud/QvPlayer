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
        DebugLogger.shared.info("App launching...")
        UserDefaults.standard.register(defaults: ["webServerEnabled": true])
        
        // Clean old cache (older than 24 hours)
        CacheManager.shared.cleanCache(olderThan: 24 * 60 * 60)
        
        if UserDefaults.standard.bool(forKey: "webServerEnabled") {
            DebugLogger.shared.info("Auto-starting Web Server...")
            WebServer.shared.start()
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
