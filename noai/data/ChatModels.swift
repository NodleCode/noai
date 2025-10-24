//
//  ChatModels.swift
//  noai
//
//  Created by Niki Izvorski on 24.10.25.
//
import Foundation

struct ChatThread: Identifiable, Hashable, Codable {
    let id: UUID
    var title: String
    var messages: [ChatMessage]
    var selectedModel: OllamaModelTag?   

    init(
        id: UUID = UUID(),
        title: String = "New Chat",
        messages: [ChatMessage] = [ChatMessage(role: .system, content: "Your noAi (Nodle) vibe coding agent to help you battle everything.")],
        selectedModel: OllamaModelTag? = nil
    ) {
        self.id = id
        self.title = title
        self.messages = messages
        self.selectedModel = selectedModel
    }
}

struct ChatMessage: Identifiable, Hashable, Codable {
    enum Role: String, Codable, CaseIterable { case system, user, assistant }
    let id: UUID
    var role: Role
    var content: String
    var thinking: String? = nil

    init(id: UUID = UUID(), role: Role, content: String, thinking: String? = nil) {
        self.id = id; self.role = role; self.content = content; self.thinking = thinking
    }
    
    var hasInlineThink: Bool { content.contains("<think>") }
    
    var thinkFromInline: String? {
        guard let open = content.range(of: "<think>") else { return nil }
        if let close = content.range(of: "</think>") {
            return String(content[open.upperBound..<close.lowerBound])
        } else {
            return String(content[open.upperBound...]) 
        }
    }
    var answerFromInline: String {
        guard let close = content.range(of: "</think>") else { return hasInlineThink ? "" : content }
        return String(content[close.upperBound...])
    }
}
