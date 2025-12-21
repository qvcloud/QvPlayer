//
//  ContentView.swift
//  QvPlayer
//
//  Created by easton on 2025/12/20.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        ZStack {
            HomeView()
            
            DebugOverlayView()
                .zIndex(999)
        }
        .onAppear {
            // Check for auto-play on app launch
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                MediaManager.shared.checkAndStartPlayback()
            }
        }
    }
}

#Preview {
    ContentView()
}
