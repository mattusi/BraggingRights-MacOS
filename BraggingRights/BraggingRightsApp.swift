//
//  BraggingRightsApp.swift
//  BraggingRights
//
//  Created by Matheus Tusi on 07/11/25.
//

import SwiftUI

@main
struct BraggingRightsApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) {
                // Remove default "New" menu item
            }
        }
    }
}
