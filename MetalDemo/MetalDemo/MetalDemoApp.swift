//
//  MetalDemoApp.swift
//  MetalDemo
//
//  Created by Michael Bedar on 9/30/25.
//

import SwiftUI
import ShadyGround

@main
struct MetalDemoApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                ContentView()
                    .tabItem { Label("Metallic", systemImage: "sparkles") }
                GrassPreview()
                    .tabItem { Label("Grass", systemImage: "leaf") }
            }
        }
    }
}
