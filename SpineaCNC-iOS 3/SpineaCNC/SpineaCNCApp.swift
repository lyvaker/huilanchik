//
//  SpineaCNCApp.swift
//  Spinea CNC Assistant — iOS port
//

import SwiftUI

@main
struct SpineaCNCApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(model)
                .preferredColorScheme(.light)
                .tint(Theme.red)
        }
    }
}
