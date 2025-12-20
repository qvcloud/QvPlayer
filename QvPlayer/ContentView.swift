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
    }
}

#Preview {
    ContentView()
}
