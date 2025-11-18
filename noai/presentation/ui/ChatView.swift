//
//  ContentView.swift
//  noai
//
//  Created by Niki Izvorski on 23.10.25.
//

import SwiftUI
import Foundation

struct ChatView: View {
    @StateObject private var vm = ChatViewModel()
    @AppStorage("sidebar.settingsExpanded") private var settingsExpanded: Bool = false
    @FocusState private var focused: Bool
    @State private var showPullSheet = false
    @State private var renamingID: UUID? = nil
    @State private var tempTitle: String = ""

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            chat
        }
        .hideNavigationSplitDivider()
        .tint(Theme.accent)
        .background(Theme.background.ignoresSafeArea(edges: .top))
        .task {
            await vm.refreshModels()
            if vm.selectedThreadID == nil { vm.selectedThreadID = vm.threads.first?.id }
            if !vm.reachable {
                vm.tryStartDaemon()
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await vm.refreshModels()
                if vm.selectedThreadID == nil { vm.selectedThreadID = vm.threads.first?.id }
            }
        }
        .toolbarBackground(.clear, for: .windowToolbar)
        .toolbarColorScheme(.dark, for: .windowToolbar)
    }

    var sidebar: some View {
        VStack(alignment: .leading, spacing: 12) {

            HStack {
                Menu {
                    Button {
                        vm.newThread(kind: .chat)
                    } label: {
                        Label("New chat", systemImage: "text.bubble")
                    }

                    Button {
                        vm.newThread(kind: .image)
                    } label: {
                        Label("New image generation", systemImage: "photo.on.rectangle.angled")
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.pencil")
                        Text("New")
                    }
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                }
                .menuStyle(.borderlessButton)
                .buttonStyle(.plain)
                .tint(Theme.textPrimary)

                Spacer()
            }
            .padding(.bottom, 2)

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(vm.threads) { thread in
                        if renamingID == thread.id {
                            HStack(spacing: 10) {
                                Image(systemName: "text.cursor")
                                    .foregroundStyle(Theme.accent).frame(width: 20)
                                TextField("Chat title", text: $tempTitle, onCommit: {
                                    vm.renameThread(thread.id, to: tempTitle)
                                    renamingID = nil
                                })
                                .textFieldStyle(.roundedBorder)
                                .foregroundStyle(Theme.textPrimary)
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06))
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.strokeSoft))
                            )
                        } else {
                            ChatRow(
                                thread: thread,
                                isSelected: vm.selectedThreadID == thread.id,
                                onSelect: { vm.selectedThreadID = thread.id },
                                onRename: {
                                    renamingID = thread.id
                                    tempTitle = thread.title
                                },
                                onDelete: { vm.deleteThread(thread.id) },
                                onExportMarkdown: { vm.exportThreadAsMarkdown(thread.id) },
                                onExportJSON: { vm.exportThreadAsJSON(thread.id) }
                            )
                        }
                    }
                }
                .padding(.vertical, 6)
            }
            .frame(minHeight: 220)

            Divider().overlay(Theme.strokeSoft).padding(.top, 4)

            SidebarSection(title: "Settings", isExpanded: $settingsExpanded) {
                HStack {
                    Circle()
                        .fill(vm.reachable ? Theme.accent : Color.red)
                        .frame(width: 10, height: 10)

                    Text(vm.reachable ? "Connected" : "Not connected")
                        .foregroundStyle(Theme.textSecondary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Host")
                        .foregroundStyle(Theme.textSecondary)

                    TextField(
                        "http://127.0.0.1:11434",
                        text: Binding(
                            get: { vm.baseURL.absoluteString },
                            set: { newVal in
                                if let u = URL(string: newVal) {
                                    vm.baseURL = u
                                    Task { await vm.refreshModels() }
                                }
                            }
                        )
                    )
                    .textFieldStyle(.roundedBorder)
                    .foregroundStyle(Theme.textPrimary)
                }

                GroupBox("Decoding") {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("temperature")
                            Slider(value: $vm.options.temperature, in: 0...1)
                            Text(String(format: "%.2f", vm.options.temperature))
                        }
                        HStack {
                            Text("top_p")
                            Slider(value: $vm.options.top_p, in: 0...1)
                            Text(String(format: "%.2f", vm.options.top_p))
                        }
                        HStack {
                            Text("top_k")
                            Slider(
                                value: Binding(
                                    get: { Double(vm.options.top_k) },
                                    set: { vm.options.top_k = Int($0) }
                                ),
                                in: 1...100
                            )
                            Text("\(vm.options.top_k)")
                        }
                        HStack {
                            Text("num_predict")
                            Slider(
                                value: Binding(
                                    get: { Double(vm.options.num_predict) },
                                    set: { vm.options.num_predict = Int($0) }
                                ),
                                in: 64...8192
                            )
                            Text("\(vm.options.num_predict)")
                        }
                    }
                    .foregroundStyle(Theme.textSecondary)
                }
                .foregroundStyle(Theme.textSecondary)

                Button {
                    vm.exportAllThreadsAsJSON()
                } label: {
                    Label("Export All Chats (JSON)", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(Theme.textSecondary)

                Divider()
                    .overlay(Theme.strokeSoft.opacity(0.6))
                    .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label("Image generation", systemImage: "photo.on.rectangle.angled")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)

                        Spacer()

                        Text(vm.isImageModelConfigured ? "Ready" : "Not configured")
                            .font(.caption2)
                            .foregroundStyle(vm.isImageModelConfigured ? Theme.accent : Color.red)
                    }

                    Text(vm.sdModelFolderPath ?? "No Stable Diffusion model folder selected")
                        .font(.caption2)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    HStack {
                        Button {
                            vm.chooseStableDiffusionFolder()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "folder")
                                Text(vm.sdModelFolderPath == nil ? "Choose folder…" : "Change folder…")
                            }
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Theme.bgPanel.opacity(0.9))
                            )
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Theme.textPrimary)

                        if vm.sdModelFolderPath != nil {
                            Button {
                                vm.clearStableDiffusionFolder()
                            } label: {
                                Text("Clear")
                                    .font(.caption2)
                            }
                            .buttonStyle(.borderless)
                            .foregroundStyle(Theme.textSecondary)
                        }

                        Spacer()
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding()
        .frame(minWidth: 280)
        .background(
            Theme.background
                .overlay(.black.opacity(0.28))
                .ignoresSafeArea(edges: .top)
        )
    }

    var chat: some View {
        VStack(spacing: 0) {
            if let idx = vm.selectedThreadIndex {
                let thread = vm.threads[idx]

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(Array(thread.messages.enumerated()), id: \.element.id) { i, msg in
                                let isLast = i == thread.messages.count - 1
                                let showTyping = vm.streaming && isLast && msg.role == .assistant && msg.content.isEmpty
                                ChatBubble(
                                    message: msg,
                                    typingModel: showTyping ? (vm.streamingModelName ?? thread.selectedModel?.model ?? "model") : nil,
                                    onSave: { data in
                                        vm.saveImage(data)
                                    }
                                )
                                .id(msg.id)
                            }
                        }
                        .padding()
                    }
                    .onAppear {
                        scrollToBottom(proxy, thread: thread)
                    }
                    .onChange(of: thread.messages) { _, _ in
                        scrollToBottom(proxy, thread: thread)
                    }
                }
                .id(thread.id)
                
                if thread.kind == .image && vm.imageGenerating {
                    HStack(alignment: .top, spacing: 8) {
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(spacing: 8) {
                                Text("Generating image with Stable Diffusion")
                                    .font(.caption)
                                    .foregroundStyle(Theme.accent)
                                
                                ImageGeneratingDots()
                            }
                            .padding(12)
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                }

                Divider().overlay(Theme.strokeSoft)

                if thread.kind == .image {
                    ComposerPill(
                        text: $vm.input,
                        models: [],
                        selection: .constant(nil),
                        disabled: vm.streaming,
                        mode: .image,
                        onSend: { Task { await vm.send() } }
                    )
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Theme.background)
                } else {
                    ComposerPill(
                        text: $vm.input,
                        models: vm.models,
                        selection: Binding(
                            get: { vm.threads[idx].selectedModel },
                            set: { vm.threads[idx].selectedModel = $0; vm.saveThreads() }
                        ),
                        disabled: vm.streaming || !vm.reachable,
                        mode: .chat,
                        onSend: { Task { await vm.send() } }
                    )
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Theme.background)
                }

            } else {
                VStack {
                    Spacer()
                    Text("No chat selected").foregroundStyle(Theme.textSecondary)
                    Button("Start a New Chat") { vm.newThread() }
                        .buttonStyle(.borderedProminent)
                    Spacer()
                }
            }
        }
        .background(Theme.background.ignoresSafeArea())
    }
    
    private func scrollToBottom(_ proxy: ScrollViewProxy, thread: ChatThread) {
        guard let last = thread.messages.last else { return }

        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }
}

#Preview {
    ChatView()
}
