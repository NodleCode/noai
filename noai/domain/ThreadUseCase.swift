//
//  ThreadUseCase.swift
//  noai
//
//  Created by Niki Izvorski on 24.10.25.
//

class ThreadUseCase {
    let store  = ThreadStore.shared
    
    func load() -> [ChatThread] {
        store.load()
    }
    
    func saveThreads(threads: [ChatThread]) {
        store.save(threads)
    }
}
