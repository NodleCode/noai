//
//  ChatRow.swift
//  noai
//
//  Created by Niki Izvorski on 24.10.25.
//

import SwiftUI
import AppKit

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
    private var isImageThread: Bool { thread.kind == .image }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                Image(systemName: isImageThread ? "photo.on.rectangle.angled" : "message.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isImageThread ? Theme.accent : Theme.accent)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(thread.title.isEmpty ? (isImageThread ? "Image Generation" : "New Chat") : thread.title)
                        .lineLimit(1)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    
                    if isImageThread {
                        Text("Stable Diffusion")
                            .font(.caption2)
                            .foregroundStyle(Theme.textSecondary)
                    } else if let m = thread.selectedModel?.model {
                        Text(m)
                            .font(.caption2)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }

                Spacer(minLength: 8)

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

struct MessageSegment: Identifiable {
    enum Kind {
        case text(String)
        case code(language: String?, code: String)
    }

    let id = UUID()
    let kind: Kind
}

func parseMessageSegments(_ text: String) -> [MessageSegment] {
    var segments: [MessageSegment] = []
    var remaining = Substring(text)

    while let fenceRange = remaining.range(of: "```") {
        let before = remaining[..<fenceRange.lowerBound]
        if !before.isEmpty {
            segments.append(
                MessageSegment(kind: .text(String(before)))
            )
        }

        var afterFence = remaining[fenceRange.upperBound...]

        var language: String? = nil
        if let newline = afterFence.firstIndex(of: "\n") {
            let langPart = afterFence[..<newline]
            let trimmed = langPart.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                language = trimmed
            }
            afterFence = afterFence[afterFence.index(after: newline)...]
        } else {
            let code = afterFence.trimmingCharacters(in: .whitespacesAndNewlines)
            if !code.isEmpty {
                segments.append(
                    MessageSegment(kind: .code(language: language, code: code))
                )
            }
            return segments
        }

        if let closingRange = afterFence.range(of: "```") {
            let code = afterFence[..<closingRange.lowerBound]
            let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedCode.isEmpty {
                segments.append(
                    MessageSegment(kind: .code(language: language, code: trimmedCode))
                )
            }
            remaining = afterFence[closingRange.upperBound...]
        } else {
            let trimmedCode = afterFence.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedCode.isEmpty {
                segments.append(
                    MessageSegment(kind: .code(language: language, code: trimmedCode))
                )
            }
            return segments
        }
    }

    if !remaining.isEmpty {
        segments.append(
            MessageSegment(kind: .text(String(remaining)))
        )
    }

    return segments
}

struct CodeBlockView: View {
    let language: String?
    let code: String

    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if let language, !language.isEmpty {
                    Text(language)
                        .font(.caption2.monospaced())
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.vertical, 2)
                        .padding(.horizontal, 8)
                        .background(Theme.bgPanel)
                        .clipShape(Capsule())
                }

                Spacer(minLength: 0)

                Button {
                    copyToClipboard()
                    withAnimation(.easeInOut(duration: 0.12)) {
                        copied = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        withAnimation(.easeInOut(duration: 0.12)) {
                            copied = false
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 11, weight: .semibold))
                        Text(copied ? "Copied" : "Copy")
                            .font(.caption2)
                    }
                }
                .buttonStyle(.borderless)
                .foregroundStyle(Theme.textSecondary)
            }

            ScrollView(.horizontal, showsIndicators: true) {
                Text(code)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundStyle(Theme.textPrimary)
                    .textSelection(.enabled)
                    .padding(.vertical, 2)
                    .frame(alignment: .topLeading)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(0.28))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Theme.strokeSoft)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func copyToClipboard() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(code, forType: .string)
    }
}

struct ImageGeneratingDots: View {
    @State private var phase: Int = 0

    private let timer = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .frame(width: 5, height: 5)
                    .scaleEffect(phase == index ? 1.0 : 0.5)
                    .opacity(phase == index ? 1.0 : 0.25)
            }
        }
        .foregroundStyle(Theme.accent)
        .onReceive(timer) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                phase = (phase + 1) % 3
            }
        }
    }
}

struct ChatBubble: View {
    let message: ChatMessage
    var typingModel: String? = nil
    var onSave: (Data) -> Void
    var isUser: Bool { message.role == .user }
    var isSystem: Bool { message.role == .system }
    
    @State private var hoveringImage = false

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
                        let segments = parseMessageSegments(answer)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(segments) { segment in
                                switch segment.kind {
                                case .text(let t):
                                    let trimmed = t.trimmingCharacters(in: .whitespacesAndNewlines)
                                    if !trimmed.isEmpty {
                                        Text(trimmed)
                                            .textSelection(.enabled)
                                            .foregroundStyle(isSystem ? Theme.textSecondary : Theme.accent)
                                            .multilineTextAlignment(.leading)
                                    }
                                case .code(let language, let code):
                                    CodeBlockView(language: language, code: code)
                                }
                            }
                        }
                        .padding(12)
                        .background(Theme.bubble(isSystem: isSystem))
                    }
                }
                
                if let data = message.imageData,
                   let nsImage = NSImage(data: data) {
                    VStack(alignment: .leading, spacing: 6) {
                        ZStack(alignment: .topTrailing) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: 320)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(Theme.strokeSoft)
                                )
                                .contextMenu {
                                    Button {
                                        onSave(data)
                                    } label: {
                                        Text("Save PNG…")
                                        Image(systemName: "square.and.arrow.down")
                                    }
                                }

                            if hoveringImage {
                                Button {
                                    onSave(data)
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "square.and.arrow.down")
                                            .foregroundStyle(Theme.textPrimary)
                                        Text("Save")
                                            .foregroundStyle(Theme.textPrimary)
                                    }
                                    .font(.caption2)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Theme.bgPanel)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(Theme.strokeSoft)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                }
                                .buttonStyle(.plain)
                                .padding(8)
                            }
                        }
                        .onHover { hovering in
                            hoveringImage = hovering  
                        }
                    }
                    .padding(.bottom, 4)
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
