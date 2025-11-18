//
//  ImageGenEngine.swift
//  noai
//
//  Created by Niki Izvorski on 17.11.25.
//

import Foundation
import StableDiffusion
import CoreML
import AppKit

final class ImageGenEngine {
    static let shared = ImageGenEngine()

    private var pipeline: StableDiffusionPipeline?
    private var modelFolderURL: URL?

    func setModelFolder(url: URL) {
        modelFolderURL = url
        pipeline = nil
    }

    private func loadIfNeeded() throws {
        guard let url = modelFolderURL else {
            throw NSError(domain: "ImageGen", code: 0,
                          userInfo: [NSLocalizedDescriptionKey: "Model folder not set"])
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

    private func generateSync(prompt: String) throws -> NSImage {
        try loadIfNeeded()

        guard let pipeline else {
            throw NSError(domain: "ImageGen", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Pipeline not loaded"])
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
            throw NSError(domain: "ImageGen", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "No image generated"])
        }

        let size = NSSize(width: cgImage.width, height: cgImage.height)
        return NSImage(cgImage: cgImage, size: size)
    }

    func generate(prompt: String) async throws -> NSImage {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let img = try self.generateSync(prompt: prompt)
                    continuation.resume(returning: img)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
