import Foundation
import Vision
import UIKit

/// Vision Skill — analyzes images using Apple's Vision framework.
/// Performs OCR (text recognition) locally on device. For object recognition,
/// requires a CoreML model or a remote vision provider.
final class VisionSkill: AgentSkill, @unchecked Sendable {

    let id = "vision"
    let name = "Analyse d'Images"
    let description = "Analyse une image fournie par l'utilisateur. Identifie du texte (OCR), détecte des objets et informations visuelles."
    let category: SkillCategory = .vision
    let requiredPermissions: [SkillPermission] = [.camera]

    var inputSchema: JSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "imagePath": .object([
                    "type": .string("string"),
                    "description": .string("Chemin local de l'image à analyser")
                ]),
                "task": .object([
                    "type": .string("string"),
                    "description": .string("Type d'analyse: 'ocr' (reconnaissance de texte), 'objects' (détection d'objets), 'all' (tout)"),
                    "enum": .array([.string("ocr"), .string("objects"), .string("all")]),
                    "default": .string("all")
                ])
            ]),
            "required": .array([.string("imagePath")])
        ])
    }

    var outputSchema: JSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "recognizedText": .string("Texte reconnu dans l'image"),
                "objects": .array([.string("Objets détectés")]),
                "confidence": .number(0.0)
            ])
        ])
    }

    func execute(input: JSONValue, context: SkillExecutionContext) async throws -> SkillResult {
        guard let imagePath = input["imagePath"]?.stringValue, !imagePath.isEmpty else {
            throw SkillError.invalidInput("Le paramètre 'imagePath' est requis")
        }

        let task = input["task"]?.stringValue ?? "all"

        guard let image = UIImage(contentsOfFile: imagePath), let cgImage = image.cgImage else {
            throw SkillError.invalidInput("Impossible de charger l'image: \(imagePath)")
        }

        context.emitEvent(.statusChanged("Analyse de l'image..."))

        var recognizedText = ""
        var objects: [String] = []

        // OCR using Vision framework
        if task == "ocr" || task == "all" {
            recognizedText = try await performOCR(on: cgImage)
            context.emitEvent(.statusChanged("Texte reconnu: \(recognizedText.count) caractères"))
        }

        // Object detection using Vision (requires iOS 15+ for built-in model)
        if task == "objects" || task == "all" {
            objects = try await detectObjects(on: cgImage)
            context.emitEvent(.statusChanged("Objets détectés: \(objects.count)"))
        }

        let output: JSONValue = .object([
            "recognizedText": .string(recognizedText),
            "objects": .array(objects.map { .string($0) }),
            "imageSize": .object([
                "width": .number(Double(image.size.width)),
                "height": .number(Double(image.size.height))
            ])
        ])

        return SkillResult(
            output: output,
            summary: "Image analysée: \(recognizedText.count) caractères de texte, \(objects.count) objet(s) détecté(s)"
        )
    }

    // MARK: - OCR

    private func performOCR(on cgImage: CGImage) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let text = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
                continuation.resume(returning: text)
            }

            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["fr-FR", "en-US"]
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Object Detection

    private func detectObjects(on cgImage: CGImage) async throws -> [String] {
        // Use Vision's built-in object detection (if available)
        // This uses the classifying model available on iOS 15+
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNClassifyImageRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                let observations = request.results as? [VNClassificationObservation] ?? []
                // Filter to high-confidence results
                let topResults = observations
                    .filter { $0.confidence > 0.3 }
                    .prefix(10)
                    .map { "\($0.identifier) (\(Int($0.confidence * 100))%)" }

                continuation.resume(returning: Array(topResults))
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: []) // Object detection may not be available on all devices
            }
        }
    }
}
