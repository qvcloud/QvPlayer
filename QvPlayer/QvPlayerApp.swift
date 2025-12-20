//
//  QvPlayerApp.swift
//  QvPlayer
//
//  Created by easton on 2025/12/20.
//

import SwiftUI

@main
struct QvPlayerApp: App {
    init() {
        WebServer.shared.start()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
