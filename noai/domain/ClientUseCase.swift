//
//  ClientUseCase.swift
//  noai
//
//  Created by Niki Izvorski on 24.10.25.
//

import Foundation
import Combine

@MainActor
final class ClientUseCase: ObservableObject {
    @Published var baseURL: URL
    @Published var reachable: Bool

    private let client = OllamaClient()
    private var cancellables = Set<AnyCancellable>()

    init() {
        self.baseURL = client.baseURL
        self.reachable = client.reachable

        client.$baseURL
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.baseURL = $0 }
            .store(in: &cancellables)

        client.$reachable
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.reachable = $0 }
            .store(in: &cancellables)

        $baseURL
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] in self?.client.baseURL = $0 }
            .store(in: &cancellables)
    }

    func checkHealth() async {
        await client.checkHealth()
        self.reachable = client.reachable
    }

    func listModels() async throws -> [OllamaModelTag] {
        try await client.listModels()
    }

    func chatStream(
        model: String,
        messages: [ChatMessage],
        options: OllamaClient.ChatOptions
    ) -> AsyncThrowingStream<OllamaClient.ChatDelta, Error> {
        client.chatStream(model: model, messages: messages, options: options)
    }

    func pullStream(name: String) -> AsyncThrowingStream<String, Error> {
        client.pullStream(name: name)
    }

    func tryStartDaemon() {
        client.tryStartDaemon()
    }
}
