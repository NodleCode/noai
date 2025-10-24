//
//  noaiApp.swift
//  noai
//
//  Created by Niki Izvorski on 23.10.25.
//

import SwiftUI

@main
struct noaiApp: App {
    var body: some Scene {
        WindowGroup {
            ChatView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)     
    }
}
