//
//  ChatModels.swift
//  noai
//
//  Created by Niki Izvorski on 24.10.25.
//
import Foundation

struct ChatThread: Identifiable, Hashable, Codable {
    enum Kind: String, Codable {
        case chat
        case image
    }

    let id: UUID
    var title: String
    var messages: [ChatMessage]
    var selectedModel: OllamaModelTag?
    var kind: Kind  

    init(
        id: UUID = UUID(),
        title: String = "New Chat",
        messages: [ChatMessage] = [
            ChatMessage(
                role: .system,
                content: "Your noAi (Nodle) vibe coding agent to help you battle everything."
            )
        ],
        selectedModel: OllamaModelTag? = nil,
        kind: Kind = .chat
    ) {
        self.id = id
        self.title = title
        self.messages = messages
        self.selectedModel = selectedModel
        self.kind = kind
    }
    
    enum CodingKeys: String, CodingKey {
        case id, title, messages, selectedModel, kind
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        messages = try c.decode([ChatMessage].self, forKey: .messages)
        selectedModel = try c.decodeIfPresent(OllamaModelTag.self, forKey: .selectedModel)
        kind = try c.decodeIfPresent(Kind.self, forKey: .kind) ?? .chat
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(messages, forKey: .messages)
        try c.encodeIfPresent(selectedModel, forKey: .selectedModel)
        try c.encode(kind, forKey: .kind)
    }
}

struct ChatMessage: Identifiable, Hashable, Codable {
    enum Role: String, Codable, CaseIterable { case system, user, assistant }
    let id: UUID
    var role: Role
    var content: String
    var thinking: String? = nil
    var imageData: Data? = nil
    
    var hasImage: Bool {
        imageData != nil
    }
    
    init(
        id: UUID = UUID(),
        role: Role,
        content: String,
        thinking: String? = nil,
        imageData: Data? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.thinking = thinking
        self.imageData = imageData
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
