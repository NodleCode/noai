//
//  Theme.swift
//  noai
//
//  Created by Niki Izvorski on 24.10.25.
//

import SwiftUI

struct Theme {
    static let accent      = Color(red: 0.16, green: 0.95, blue: 0.44)  // Nodle glow green
    static let accentSoft  = Color(red: 0.10, green: 0.60, blue: 0.33)  // darker green
    static let bgDeep      = Color(red: 0.04, green: 0.08, blue: 0.06)  // #0B140F-ish
    static let bgPanel     = Color.black.opacity(0.18)
    static let strokeSoft  = Color.white.opacity(0.08)
    static let textPrimary = Color.white.opacity(0.92)
    static let textSecondary = Color.white.opacity(0.6)

    static var background: some View {
        // dark green with corner glow, matches app icon vibe
        LinearGradient(
            colors: [bgDeep, Color(red: 0.02, green: 0.14, blue: 0.10)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        .overlay(
            RadialGradient(
                colors: [accent.opacity(0.14), .clear],
                center: .center, startRadius: 40, endRadius: 520
            )
        )
    }

    static func bubble(isSystem: Bool) -> some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(isSystem ? Color.white.opacity(0.04) : Theme.bgPanel)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Theme.accent.opacity(isSystem ? 0.12 : 0.22))
            )
            .shadow(color: Theme.accent.opacity(isSystem ? 0.10 : 0.22), radius: 8, y: 1)
    }

    static var composer: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color.white.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Theme.strokeSoft)
            )
    }
}



