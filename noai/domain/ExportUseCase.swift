//
//  ExportUseCase.swift
//  noai
//
//  Created by Niki Izvorski on 24.10.25.
//

import Foundation
import AppKit

class ExportUseCase {
    
    func safeFilename(_ s: String, ext: String) -> String {
        let base = s
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"[^\w\s\-\._]+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: " ", with: "_")
        return (base.isEmpty ? "chat" : base) + "." + ext
    }
    
    func exportThreadAsJSON(_ id: UUID, threads: [ChatThread]) {
        guard let t = threads.first(where: { $0.id == id }) else { return }
        do {
            let data = try JSONEncoder().encode(t) 
            let panel = NSSavePanel()
            panel.allowedFileTypes = ["json"]
            panel.nameFieldStringValue = safeFilename(t.title, ext: "json")
            panel.canCreateDirectories = true
            if panel.runModal() == .OK, let url = panel.url {
                try data.write(to: url, options: .atomic)
            }
        } catch { print("export json error:", error) }
    }
    
    func exportThreadAsMarkdown(_ id: UUID, threads: [ChatThread]) {
        guard let t = threads.first(where: { $0.id == id }) else { return }
        
        var lines: [String] = []
        lines.append("# \(t.title.isEmpty ? "Chat" : t.title)")
        if let m = t.selectedModel?.model {
            lines.append("> Model: `\(m)`")
        }
        lines.append("> Exported: \(ISO8601DateFormatter().string(from: Date()))")
        lines.append("")
        
        for msg in t.messages {
            switch msg.role {
            case .system:     lines.append("### System")
            case .user:       lines.append("### You")
            case .assistant:  lines.append("### Agent")
            }
            lines.append("")
            
            if let think = msg.thinking, !think.isEmpty {
                lines.append("<details>")
                lines.append("<summary>Reasoning</summary>")
                lines.append("")
                lines.append("```text")
                lines.append(think)
                lines.append("```")
                lines.append("</details>")
                lines.append("")
            } else if msg.hasInlineThink, let think = msg.thinkFromInline {
                lines.append("<details>")
                lines.append("<summary>Reasoning</summary>")
                lines.append("")
                lines.append("```text")
                lines.append(think)
                lines.append("```")
                lines.append("</details>")
                lines.append("")
            }
            
            let answer = msg.hasInlineThink ? msg.answerFromInline : msg.content
            if !answer.isEmpty {
                if answer.contains("```") || answer.contains("\n") {
                    lines.append(answer)
                } else {
                    lines.append(answer)
                }
                lines.append("")
            }
        }
        
        let md = lines.joined(separator: "\n")
        let panel = NSSavePanel()
        panel.allowedFileTypes = ["md", "markdown", "txt"]
        panel.nameFieldStringValue = safeFilename(t.title, ext: "md")
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            do { try md.data(using: .utf8)?.write(to: url, options: .atomic) }
            catch { print("export markdown error:", error) }
        }
    }
    
    func exportAllThreadsAsJSON(threads: [ChatThread]) {
        do {
            let data = try JSONEncoder().encode(threads)
            let panel = NSSavePanel()
            panel.allowedFileTypes = ["json"]
            panel.nameFieldStringValue = "noai_chats.json"
            panel.canCreateDirectories = true
            if panel.runModal() == .OK, let url = panel.url {
                try data.write(to: url, options: .atomic)
            }
        } catch { print("export all json error:", error) }
    }
}
