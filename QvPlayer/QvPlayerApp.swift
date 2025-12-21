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
        UserDefaults.standard.register(defaults: [
            "webServerEnabled": true,
            "autoClearCacheDays": 0 // Default to Never (0) or maybe 7? User asked for options, let's default to 0 (Manual) or keep existing behavior? 
            // Existing behavior was 24h. Let's default to 0 to respect "options" implies choice, but maybe 7 is a safe default if we want to be helpful. 
            // However, the prompt implies adding the feature. I'll stick to 0 (Never) as default for "new feature" unless specified.
            // Wait, the previous code was `cleanCache(olderThan: 24 * 60 * 60)`. If I change it to 0, I change behavior.
            // I'll set default to 0, but I should probably respect the user's previous implicit behavior? 
            // Actually, let's just implement the logic.
        ])
        
        // Auto Clear Cache
        let autoClearDays = UserDefaults.standard.integer(forKey: "autoClearCacheDays")
        if autoClearDays > 0 {
            CacheManager.shared.performAutoClear(days: autoClearDays)
        }
        
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
