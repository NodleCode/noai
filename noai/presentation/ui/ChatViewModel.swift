//
//  ChatViewModel.swift
//  noai
//
//  Created by Niki Izvorski on 24.10.25.
//
import SwiftUI
import Combine

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var models: [OllamaModelTag] = []
    @Published var streamingModelName: String? = nil
    @Published var threads: [ChatThread]
    @Published var selectedThreadID: UUID?
    @Published var input: String = ""
    @Published var streaming: Bool = false
    @Published var options = OllamaClient.ChatOptions()
    @Published var pullName: String = ""
    @Published var pullLines: [String] = []
    @Published var pulling: Bool = false
    @Published var reachable: Bool = false
    @Published var baseURL: URL = URL(string: "http://127.0.0.1:11434")!
    let exportUseCase = ExportUseCase()
    let threadUseCase = ThreadUseCase()
    let clientUseCase = ClientUseCase()
    private var cancellables = Set<AnyCancellable>()
    
    var selectedThreadIndex: Int? { threads.firstIndex { $0.id == (selectedThreadID ?? threads.first?.id) } }
    
    init() {
        let loaded = threadUseCase.load()
        self.threads = loaded.isEmpty ? [ChatThread()] : loaded
        self.selectedThreadID = threads.first?.id
        self.baseURL = clientUseCase.baseURL
        self.reachable = clientUseCase.reachable
        
        clientUseCase.$baseURL
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.baseURL = $0 }
            .store(in: &cancellables)
        
        clientUseCase.$reachable
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.reachable = $0 }
            .store(in: &cancellables)
        
        $baseURL
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] in self?.clientUseCase.baseURL = $0 }
            .store(in: &cancellables)
    }
    
    func saveThreads() {
        threadUseCase.saveThreads(threads: threads)
    }
    
    func newThread(prefill: String? = nil) {
        var t = ChatThread()
        if let first = prefill, !first.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            t.title = makeTitle(from: first)
        }
        t.selectedModel = models.first
        threads.insert(t, at: 0)
        selectedThreadID = t.id
        saveThreads()
    }
    
    private func makeTitle(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let firstLine = trimmed.components(separatedBy: .newlines).first ?? trimmed
        let clipped = firstLine.prefix(40)
        return String(clipped).isEmpty ? "New Chat" : String(clipped)
    }
    
    func refreshModels() async {
        await clientUseCase.checkHealth()
        guard clientUseCase.reachable else { return }
        do {
            let tags = try await clientUseCase.listModels()
            self.models = tags.sorted { $0.model < $1.model }
            for i in threads.indices where threads[i].selectedModel == nil {
                threads[i].selectedModel = tags.first
            }
            if selectedThreadID == nil { selectedThreadID = threads.first?.id }
            saveThreads()
        } catch { print("listModels error: \(error)") }
    }
    
    func send() async {
        guard clientUseCase.reachable,
              let idx = selectedThreadIndex
        else { return }
        
        var modelName = threads[idx].selectedModel?.model
        if modelName == nil { modelName = models.first?.model }
        guard let model = modelName,
              !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return }
        
        streamingModelName = model
        
        if threads[idx].title == "New Chat" {
            threads[idx].title = makeTitle(from: input)
        }
        
        if threads[idx].messages.first?.role == .system {
            threads[idx].messages.removeFirst()
        }
        
        let userMsg = ChatMessage(role: .user, content: input)
        input = ""
        threads[idx].messages.append(userMsg)
        threads[idx].messages.append(ChatMessage(role: .assistant, content: "", thinking: ""))
        streaming = true
        
        do {
            let aidx = threads[idx].messages.count - 1
            for try await delta in clientUseCase.chatStream(model: model, messages: threads[idx].messages, options: options) {
                guard threads.indices.contains(idx),
                      threads[idx].messages.indices.contains(aidx) else {
                    break
                }
                
                if let t = delta.thinking, !t.isEmpty {
                    threads[idx].messages[aidx].thinking = (threads[idx].messages[aidx].thinking ?? "") + t
                }
                if let c = delta.content, !c.isEmpty {
                    threads[idx].messages[aidx].content += c
                }
                if delta.done {
                    if threads[idx].messages[aidx].thinking?.isEmpty ?? true,
                       threads[idx].messages[aidx].hasInlineThink {
                        threads[idx].messages[aidx].thinking = threads[idx].messages[aidx].thinkFromInline
                        threads[idx].messages[aidx].content  = threads[idx].messages[aidx].answerFromInline
                    }
                }
            }
        } catch {
            threads[idx].messages.append(ChatMessage(role: .assistant, content: "(error: \(error.localizedDescription))"))
        }
        
        streaming = false
        streamingModelName = nil
        saveThreads()
    }
    
    func pull() async {
        guard !pullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        pulling = true; pullLines.removeAll()
        do {
            for try await line in clientUseCase.pullStream(name: pullName) { pullLines.append(line) }
            await refreshModels()
        } catch { pullLines.append("error: \(error.localizedDescription)") }
        pulling = false
    }
    
    func deleteThread(_ id: UUID) {
        if let i = threads.firstIndex(where: { $0.id == id }) {
            threads.remove(at: i)
            if threads.isEmpty { newThread() }
            selectedThreadID = threads.first?.id
            saveThreads()
        }
    }
    
    func renameThread(_ id: UUID, to newTitle: String) {
        guard let i = threads.firstIndex(where: { $0.id == id }) else { return }
        threads[i].title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "New Chat" : newTitle
        saveThreads()
    }
    
    func tryStartDaemon() {
        clientUseCase.tryStartDaemon()
    }
    
    func safeFilename(_ s: String, ext: String) -> String {
        exportUseCase.safeFilename(s, ext: ext)
    }
    
    func exportThreadAsJSON(_ id: UUID) {
        exportUseCase.exportThreadAsJSON(id, threads: threads)
    }
    
    func exportThreadAsMarkdown(_ id: UUID) {
        exportUseCase.exportThreadAsMarkdown(id, threads: threads)
    }
    
    func exportAllThreadsAsJSON() {
        exportUseCase.exportAllThreadsAsJSON(threads: threads)
    }
}
