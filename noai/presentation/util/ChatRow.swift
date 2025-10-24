//
//  ChatRow.swift
//  noai
//
//  Created by Niki Izvorski on 24.10.25.
//

import SwiftUI

struct TypingBubble: View {
    let modelName: String
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles").foregroundStyle(Theme.accent)
            Text(modelName).font(.caption).foregroundStyle(Theme.textSecondary)
            TimelineView(.periodic(from: .now, by: 0.5)) { timeline in
                let dots = ["", ".", "..", "..."]
                let i = Int(timeline.date.timeIntervalSince1970 * 2) % dots.count
                Text("Thinking\(dots[i])")
                    .font(.callout).monospaced()
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(10)
        .background(Theme.bgPanel)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.strokeSoft))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct ChatRow: View {
    let thread: ChatThread
    let isSelected: Bool
    var onSelect: () -> Void
    var onRename: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    var onExportMarkdown: (() -> Void)? = nil
    var onExportJSON: (() -> Void)? = nil
    @State private var hovering = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                Image(systemName: "message.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(thread.title.isEmpty ? "New Chat" : thread.title)
                        .lineLimit(1)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)

                    if let m = thread.selectedModel?.model {
                        Text(m)
                            .font(.caption2)
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.bgPanel)
                            .clipShape(Capsule())
                    }
                }

                Spacer(minLength: 8)

                // chevron on hover
                if hovering || isSelected {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .opacity(0.8)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill( (isSelected ? Theme.accent.opacity(0.16) : hovering ? Color.white.opacity(0.06) : Color.clear) )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(isSelected ? Theme.accent.opacity(0.35) : Theme.strokeSoft)
                    )
            )
            .animation(.easeInOut(duration: 0.15), value: isSelected)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .contextMenu {
            Button("Rename", action: { onRename?() })
                Divider()
                Button("Export as Markdown…") {
                    onExportMarkdown?()
                }
                Button("Export as JSON…") {
                    onExportJSON?()
                }
                Divider()
                Button(role: .destructive, action: { onDelete?() }) { Text("Delete") }
        }
    }
}



struct ChatBubble: View {
    let message: ChatMessage
    var typingModel: String? = nil

    var isUser: Bool { message.role == .user }
    var isSystem: Bool { message.role == .system }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if isUser { Spacer(minLength: 40) }
            VStack(alignment: .leading, spacing: 6) {
                Text(isSystem ? "Welcome Message" : (isUser ? "You" : "Agent"))
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)

                if let typingModel, message.role == .assistant, message.content.isEmpty, (message.thinking?.isEmpty ?? true) {
                    TypingBubble(modelName: typingModel)
                } else {
                    let hasInline = message.hasInlineThink
                    let inlineThinkText = message.thinkFromInline ?? ""
                    let parsedThinkText = message.thinking ?? ""
                    let thinkTextToShow = !parsedThinkText.isEmpty ? parsedThinkText
                                          : (hasInline ? inlineThinkText : "")

                    let finalAnswer = hasInline ? message.answerFromInline : message.content
                    let isStreamingForThis = typingModel != nil || (message.role == .assistant && finalAnswer.isEmpty)

                    if !thinkTextToShow.isEmpty {
                        ExpandableThinking(
                            text: thinkTextToShow,
                            isStreaming: isStreamingForThis,
                            hasFinalAnswer: !finalAnswer.isEmpty
                        )
                    } else if hasInline && finalAnswer.isEmpty {
                        ExpandableThinking(
                            text: inlineThinkText.isEmpty ? "Thinking…" : inlineThinkText,
                            isStreaming: true,
                            hasFinalAnswer: false
                        )
                    }

                    let answer = message.hasInlineThink ? message.answerFromInline : message.content
                    if !answer.isEmpty {
                        Text(answer)
                            .textSelection(.enabled)
                            .foregroundStyle(isSystem ? Theme.textSecondary : Theme.accent)
                            .padding(12)
                            .background(Theme.bubble(isSystem: isSystem))
                    }
                }
            }
            if !isUser { Spacer(minLength: 40) }
        }
        .background(.clear)
    }
}

struct ExpandableThinking: View {
    let text: String
    let autoCollapseTrigger: Bool

    @State private var expanded: Bool = true

    init(text: String, isStreaming: Bool, hasFinalAnswer: Bool) {
        self.text = text
        self.autoCollapseTrigger = (!isStreaming && hasFinalAnswer)
        _expanded = State(initialValue: isStreaming)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) { expanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "brain.head.profile")
                        .foregroundStyle(Theme.accent)
                    Text(expanded ? "Hide reasoning" : "Show reasoning")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                        .foregroundStyle(Theme.textSecondary)
                        .animation(.easeInOut(duration: 0.18), value: expanded)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                Text(text)
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(Theme.textSecondary)
                    .textSelection(.enabled)
                    .padding(10)
                    .background(Theme.bgPanel)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.strokeSoft))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .onChange(of: autoCollapseTrigger) { shouldClose in
            guard shouldClose else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation(.easeInOut(duration: 0.18)) { expanded = false }
            }
        }
    }
}
