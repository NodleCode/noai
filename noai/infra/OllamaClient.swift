//
//  OllamaClient.swift
//  noai
//
//  Created by Niki Izvorski on 24.10.25.
//
import Foundation

struct OllamaModelTag: Codable, Hashable, Identifiable {
    var id: String { model }
    let name: String?
    let model: String
    let size: Int64?
}

struct OllamaTagsResponse: Codable { let models: [OllamaModelTag] }

struct OllamaChatStreamChunk: Codable {
    struct Msg: Codable {
        let role: String?
        let content: String?
        let thinking: String?
    }
    let model: String?
    let message: Msg?
    let done: Bool?
    let error: String?
}

struct OllamaPullChunk: Codable {
    let status: String?
    let digest: String?
    let total: Int64?
    let completed: Int64?
    let error: String?
}

@MainActor
final class OllamaClient: ObservableObject {
    @Published var baseURL: URL = URL(string: "http://127.0.0.1:11434")!
    @Published var reachable: Bool = false
    
    func checkHealth() async {
        do {
            var req = URLRequest(url: baseURL.appendingPathComponent("/api/tags"))
            req.httpMethod = "GET"
            _ = try await URLSession.shared.data(for: req)
            reachable = true
        } catch {
            reachable = false
        }
    }
    
    func listModels() async throws -> [OllamaModelTag] {
        var req = URLRequest(url: baseURL.appendingPathComponent("/api/tags"))
        req.httpMethod = "GET"
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let decoded = try JSONDecoder().decode(OllamaTagsResponse.self, from: data)
        return decoded.models
    }
    
    struct ChatOptions: Codable {
        var temperature: Double = 0.4
        var top_p: Double = 0.9
        var top_k: Int = 40
        var num_predict: Int = 4096
    }
    
    struct ChatDelta {
        let thinking: String?
        let content: String?
        let done: Bool
    }
    
    func chatStream(model: String, messages: [ChatMessage], options: ChatOptions)
    -> AsyncThrowingStream<ChatDelta, Error> {
        
        struct WireMessage: Codable { let role: String; let content: String }
        struct Body: Codable {
            let model: String
            let messages: [WireMessage]
            let stream: Bool
            let options: ChatOptions
            let think: Bool?
        }
        
        func supportsThink(_ model: String) -> Bool {
            return model.hasPrefix("deepseek-r1")
        }
        
        let wire: [WireMessage] = messages.map { .init(role: $0.role.rawValue, content: $0.content) }
        let body = Body(
            model: model,
            messages: wire,
            stream: true,
            options: options,
            think: supportsThink(model) ? true : nil
        )
        
        var req = URLRequest(url: baseURL.appendingPathComponent("/api/chat"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONEncoder().encode(body)
        
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let (bytes, resp) = try await URLSession.shared.bytes(for: req)
                    guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                        throw URLError(.badServerResponse)
                    }
                    for try await line in bytes.lines {
                        guard !line.isEmpty, let data = line.data(using: .utf8) else { continue }
                        if let chunk = try? JSONDecoder().decode(OllamaChatStreamChunk.self, from: data) {
                            if let e = chunk.error, !e.isEmpty { throw NSError(domain: "Ollama", code: 1, userInfo: [NSLocalizedDescriptionKey: e]) }
                            if chunk.done == true {
                                continuation.yield(.init(thinking: nil, content: nil, done: true))
                                break
                            }
                            let t = chunk.message?.thinking
                            let c = chunk.message?.content
                            if (t?.isEmpty ?? true) && (c?.isEmpty ?? true) { continue }
                            continuation.yield(.init(thinking: t, content: c, done: false))
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    func pullStream(name: String) -> AsyncThrowingStream<String, Error> {
        struct Body: Codable { let name: String; let stream: Bool }
        var req = URLRequest(url: baseURL.appendingPathComponent("/api/pull"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONEncoder().encode(Body(name: name, stream: true))
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let (bytes, resp) = try await URLSession.shared.bytes(for: req)
                    guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
                    for try await line in bytes.lines {
                        guard !line.isEmpty, let data = line.data(using: .utf8) else { continue }
                        if let evt = try? JSONDecoder().decode(OllamaPullChunk.self, from: data) {
                            if let e = evt.error, !e.isEmpty { throw NSError(domain: "Ollama", code: 2, userInfo: [NSLocalizedDescriptionKey: e]) }
                            let pct: String
                            if let t = evt.total, let c = evt.completed, t > 0 { pct = String(format: "%.0f%%", (Double(c)/Double(t))*100.0) } else { pct = "" }
                            let line = [evt.status ?? "", pct].joined(separator: pct.isEmpty ? "" : "  ")
                            if !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { continuation.yield(line) }
                        }
                    }
                    continuation.finish()
                } catch { continuation.finish(throwing: error) }
            }
        }
    }
    
    func tryStartDaemon() {
        let candidates = ["/opt/homebrew/bin/ollama", "/usr/local/bin/ollama", "/usr/bin/ollama"]
        for path in candidates where FileManager.default.fileExists(atPath: path) {
            let p = Process(); p.executableURL = URL(fileURLWithPath: path); p.arguments = ["serve"]; try? p.run(); break
        }
    }
}

