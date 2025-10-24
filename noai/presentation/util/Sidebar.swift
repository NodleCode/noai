//
//  Sidebar.swift
//  noai
//
//  Created by Niki Izvorski on 24.10.25.
//

import SwiftUI

struct HideSplitDivider: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        DispatchQueue.main.async {
            if let split = findSplitView(in: v.window?.contentView) {
                split.isVertical = true
                split.dividerStyle = .thin
                split.wantsLayer = true
                split.layer?.backgroundColor = .clear
                split.setValue(NSColor.clear, forKey: "dividerColor")
            }
        }
        return v
    }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private func findSplitView(in view: NSView?) -> NSSplitView? {
        guard let view else { return nil }
        if let s = view as? NSSplitView { return s }
        for sub in view.subviews {
            if let s = findSplitView(in: sub) { return s }
        }
        return nil
    }
}

extension View {
    func hideNavigationSplitDivider() -> some View {
        background(HideSplitDivider())
    }
}

private func toggleSidebar() {
    NSApp.keyWindow?.firstResponder?
        .tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
}

struct SidebarSection<Content: View>: View {
    let title: String
    @Binding var isExpanded: Bool
    @ViewBuilder var content: Content
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row
            Button {
                withAnimation(.easeInOut(duration: 0.18)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "gearshape.fill")
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .animation(.easeInOut(duration: 0.18), value: isExpanded)
                    Text(title)
                        .font(.headline)
                }
                .foregroundStyle(Theme.textPrimary)
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                
            }
            .buttonStyle(.plain)
            .onHover { hovering = $0 }

            // Content
            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    content
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Theme.bgPanel)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.strokeSoft))
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}
