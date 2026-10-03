import Foundation
import Speech
import AVFoundation
import Combine

/// VoiceInput Skill — converts speech to text using Apple's Speech framework.
/// Requires microphone and speech recognition permissions.
final class VoiceInputSkill: AgentSkill, @unchecked Sendable {

    let id = "voice_input"
    let name = "Saisie Vocale"
    let description = "Transforme la voix en texte en utilisant la reconnaissance vocale d'iOS."
    let category: SkillCategory = .voice
    let requiredPermissions: [SkillPermission] = [.microphone, .speechRecognition]

    var inputSchema: JSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "language": .object([
                    "type": .string("string"),
                    "description": .string("Code langue (ex: fr-FR, en-US). Défaut: fr-FR"),
                    "default": .string("fr-FR")
                ])
            ])
        ])
    }

    var outputSchema: JSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "text": .string("Le texte reconnu"),
                "confidence": .number(0.0)
            ])
        ])
    }

    func execute(input: JSONValue, context: SkillExecutionContext) async throws -> SkillResult {
        // This skill is typically invoked from the UI via the voice button.
        // When called from the agent loop, it signals that voice input is needed.
        // The actual speech recognition is handled by the VoiceViewModel.
        throw SkillError.unsupportedOnDevice("La saisie vocale est déclenchée via le bouton microphone dans l'interface.")
    }
}

/// VoiceOutput Skill — converts text to speech using AVSpeechSynthesizer.
final class VoiceOutputSkill: AgentSkill, @unchecked Sendable {

    let id = "voice_output"
    let name = "Synthèse Vocale"
    let description = "Transforme le texte en voix en utilisant la synthèse vocale d'iOS."
    let category: SkillCategory = .voice
    let requiredPermissions: [SkillPermission] = []

    var inputSchema: JSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "text": .object([
                    "type": .string("string"),
                    "description": .string("Le texte à prononcer")
                ]),
                "language": .object([
                    "type": .string("string"),
                    "description": .string("Code langue (ex: fr-FR). Défaut: fr-FR"),
                    "default": .string("fr-FR")
                ])
            ]),
            "required": .array([.string("text")])
        ])
    }

    var outputSchema: JSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "success": .bool(true),
                "message": .string("Texte prononcé avec succès")
            ])
        ])
    }

    func execute(input: JSONValue, context: SkillExecutionContext) async throws -> SkillResult {
        guard let text = input["text"]?.stringValue, !text.isEmpty else {
            throw SkillError.invalidInput("Le paramètre 'text' est requis")
        }

        let language = input["language"]?.stringValue ?? "fr-FR"

        context.emitEvent(.statusChanged("Synthèse vocale..."))

        let success = await TextToSpeech.shared.speak(text: text, language: language)

        if !success {
            throw SkillError.custom("La synthèse vocale a échoué")
        }

        return SkillResult(
            output: .object([
                "success": .bool(true),
                "message": .string("Texte prononcé avec succès")
            ]),
            summary: "Texte prononcé"
        )
    }
}

/// Wrapper for AVSpeechSynthesizer with async/await support.
actor TextToSpeech {
    static let shared = TextToSpeech()

    private let synthesizer = AVSpeechSynthesizer()

    func speak(text: String, language: String) async -> Bool {
        await withCheckedContinuation { continuation in
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = AVSpeechSynthesisVoice(language: language)
            utterance.rate = 0.5
            utterance.pitchMultiplier = 1.0
            utterance.volume = 1.0

            let delegate = SpeechSynthesisDelegate { success in
                continuation.resume(returning: success)
            }

            // Store delegate to prevent deallocation
            self.synthesizer.delegate = delegate

            // Use a class-level reference to keep the delegate alive
            SpeechSynthesisDelegate.current = delegate

            self.synthesizer.speak(utterance)
        }
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}

private final class SpeechSynthesisDelegate: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    static var current: SpeechSynthesisDelegate?
    private let completion: (Bool) -> Void

    init(completion: @escaping (Bool) -> Void) {
        self.completion = completion
        super.init()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        completion(true)
        SpeechSynthesisDelegate.current = nil
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        completion(false)
        SpeechSynthesisDelegate.current = nil
    }
}
