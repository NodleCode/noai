//
//  ImageGenerationUseCase.swift
//  noai
//
//  Created by Niki Izvorski on 18.11.25.
//

import Foundation
import StableDiffusion
import CoreML
import AppKit
import Combine

@MainActor
final class ImageGenerationUseCase: ObservableObject {
    @Published private(set) var modelFolderPath: String?

    var isConfigured: Bool {
        modelURL != nil
    }
    
    private let sdModelBookmarkKey = "sd.model.bookmark"

    private var modelURL: URL?
    private var pipeline: StableDiffusionPipeline?

    init() {
        restoreFromDefaults()
    }

    func setModelFolder(url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }

        modelURL = url
        modelFolderPath = url.path
        pipeline = nil

        if let bookmarkData = try? url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) {
            UserDefaults.standard.set(bookmarkData, forKey: sdModelBookmarkKey)
        }
    }

    func clearModelFolder() {
        modelFolderPath = nil
        modelURL = nil
        pipeline = nil
        UserDefaults.standard.removeObject(forKey: sdModelBookmarkKey)
    }

    func generateImage(prompt: String) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let data = try self.generateImageSync(prompt: prompt)
                    continuation.resume(returning: data)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func restoreFromDefaults() {
        let defaults = UserDefaults.standard

        if let bookmarkData = defaults.data(forKey: sdModelBookmarkKey) {
            var isStale = false
            if let url = try? URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ), url.startAccessingSecurityScopedResource() {
                modelURL = url
                modelFolderPath = url.path
                return
            }
        }

        if let legacyPath = defaults.string(forKey: "sd.model.folder"),
           !legacyPath.isEmpty {
            let url = URL(fileURLWithPath: legacyPath, isDirectory: true)
            if url.startAccessingSecurityScopedResource() {
                modelURL = url
                modelFolderPath = url.path
            }
        }
    }

    private func loadPipelineIfNeeded() throws {
        guard let url = modelURL else {
            throw NSError(
                domain: "ImageGen",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Stable Diffusion model folder not set"]
            )
        }

        if pipeline == nil {
            let config = MLModelConfiguration()
            config.computeUnits = .all

            let pipe = try StableDiffusionPipeline(
                resourcesAt: url,
                controlNet: [],
                configuration: config,
                disableSafety: false,
                reduceMemory: false
            )

            try pipe.loadResources()
            pipeline = pipe
        }
    }

    private func generateImageSync(prompt: String) throws -> Data {
        try loadPipelineIfNeeded()

        guard let pipeline else {
            throw NSError(
                domain: "ImageGen",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Pipeline not loaded"]
            )
        }

        var cfg = StableDiffusionPipeline.Configuration(prompt: prompt)
        cfg.stepCount = 30
        cfg.guidanceScale = 7.5
        cfg.seed = UInt32.random(in: 0 ..< UInt32.max)
        cfg.imageCount = 1

        let cgImagesOptional = try pipeline.generateImages(
            configuration: cfg,
            progressHandler: { _ in true }
        )

        guard let cgImage = cgImagesOptional.compactMap({ $0 }).first else {
            throw NSError(
                domain: "ImageGen",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "No image generated"]
            )
        }

        let rep = NSBitmapImageRep(cgImage: cgImage)
        guard let data = rep.representation(using: .png, properties: [:]) else {
            throw NSError(
                domain: "ImageGen",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Failed to encode PNG"]
            )
        }

        return data
    }
    
    func saveImage(_ data: Data) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "image.png"

        if #available(macOS 11.0, *) {
            panel.allowedContentTypes = [.png]
        } else {
            panel.allowedFileTypes = ["png"]
        }

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try data.write(to: url)
            } catch {
                NSLog("Failed to save image: \(error.localizedDescription)")
            }
        }
    }
}
