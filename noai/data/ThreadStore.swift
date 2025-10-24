//
//  Persistence.swift
//  noai
//
//  Created by Niki Izvorski on 23.10.25.
//

import Foundation

final class ThreadStore {
    static let shared = ThreadStore()

    private let url: URL
    private let queue = DispatchQueue(label: "noai.threadstore", qos: .utility)

    init(filename: String = "threads-v1.json") {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir  = base.appendingPathComponent("noai", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        url = dir.appendingPathComponent(filename)
    }

    func load() -> [ChatThread] {
        guard let data = try? Data(contentsOf: url) else { return [ChatThread()] }
        do {
            return try JSONDecoder().decode([ChatThread].self, from: data)
        } catch {
            print("ThreadStore load error:", error)
            return [ChatThread()] 
        }
    }

    func save(_ threads: [ChatThread]) {
        queue.async {
            do {
                let data = try JSONEncoder().encode(threads)
                try data.write(to: self.url, options: [.atomic])
            } catch {
                print("ThreadStore save error:", error)
            }
        }
    }
}
