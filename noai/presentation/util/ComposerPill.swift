//
//  ComposerPill.swift
//  noai
//
//  Created by Niki Izvorski on 24.10.25.
//
import SwiftUI

enum ComposerMode {
    case chat
    case image
}

struct ComposerPill: View {
    @Binding var text: String
    let models: [OllamaModelTag]
    @Binding var selection: OllamaModelTag?
    var disabled: Bool
    var mode: ComposerMode = .chat
    var onSend: () -> Void

    private let corner: CGFloat = 24

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.composer

            HStack {
                ZStack(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("Send a message")
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.top, 8)
                            .padding(.leading, 12)
                    }

                    TextEditor(text: $text)
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.textPrimary)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .frame(minHeight: 32, maxHeight: 68, alignment: .topLeading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .onChange(of: text) { oldValue, newValue in
                            guard newValue.count == oldValue.count + 1,
                                  newValue.last == "\n" else {
                                return
                            }

                            text = String(newValue.dropLast())

                            onSend()
                        }
                }
                .padding(.trailing, 160)

                controls
                    .padding(.trailing, 12)
                    .padding(.bottom, 8)
                    .frame(maxWidth: 200, maxHeight: .infinity, alignment: .bottomTrailing)
            }
        }
        .padding(.horizontal, 2)
        .fixedSize(horizontal: false, vertical: true)
        .background(Color.clear)
    }

    private var controls: some View {
        HStack(spacing: 10) {
            if mode == .chat {
                Menu {
                    ForEach(models) { tag in
                        Button(tag.model) { selection = tag }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(selection?.model ?? "select model")
                            .lineLimit(1)
                            .foregroundStyle(Theme.textPrimary)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(Theme.bgPanel)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Theme.strokeSoft)
                    )
                }
                .menuStyle(.borderlessButton)
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Image generation")
                        .font(.caption)
                }
                .foregroundStyle(Theme.textSecondary)
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(Theme.bgPanel)
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(Theme.strokeSoft)
                )
            }

            let isEmpty = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

            Button {
                onSend()
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .bold))
                    .frame(width: 36, height: 36)
                    .foregroundStyle(.black.opacity(0.9))
                    .background((disabled || isEmpty) ? Theme.accent.opacity(0.3) : Theme.accent)
                    .clipShape(Circle())
                    .shadow(color: Theme.accent.opacity(0.5), radius: 12, y: 2)
            }
            .buttonStyle(.plain)
            .disabled(disabled || isEmpty)
        }
    }
}
