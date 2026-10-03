import SwiftUI
import Speech
import AVFoundation

/// Voice view — speech-to-text and text-to-speech interface.
struct VoiceView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @StateObject private var voiceVM = VoiceViewModel()
    @State private var recognizedText: String = ""
    @State private var isListening = false
    @State private var permissionStatus: SpeechPermissionStatus = .notDetermined

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                // Voice waveform / animation
                VoiceAnimationView(isListening: isListening)

                // Status
                VStack(spacing: 8) {
                    Text(isListening ? "Écoute..." : "Touchez pour parler")
                        .font(.title2)
                        .fontWeight(.semibold)

                    if !recognizedText.isEmpty {
                        ScrollView {
                            Text(recognizedText)
                                .font(.body)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .frame(maxHeight: 200)
                    }
                }

                // Microphone button
                Button {
                    if isListening {
                        stopListening()
                    } else {
                        startListening()
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(isListening ? Color.red : Color.accentColor)
                            .frame(width: 80, height: 80)

                        Image(systemName: isListening ? "stop.fill" : "mic.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                    }
                }
                .disabled(permissionStatus == .denied)

                if permissionStatus == .denied {
                    VStack(spacing: 8) {
                        Text("Accès au microphone requis")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button("Ouvrir les réglages") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                    }
                }

                Spacer()

                // Send to chat
                if !recognizedText.isEmpty {
                    Button {
                        sendToChat()
                    } label: {
                        Label("Envoyer au chat", systemImage: "arrow.right.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.bottom)
            .navigationTitle("Voix")
            .onAppear {
                checkPermissions()
            }
        }
    }

    private func checkPermissions() {
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        let micStatus = AVAudioApplication.shared.recordPermission

        switch speechStatus {
        case .authorized:
            if micStatus == .granted {
                permissionStatus = .granted
            } else {
                permissionStatus = .microphoneNeeded
                AVAudioApplication.requestRecordPermission { _ in }
            }
        case .notDetermined:
            permissionStatus = .notDetermined
            SFSpeechRecognizer.requestAuthorization { _ in }
        case .denied, .restricted:
            permissionStatus = .denied
        @unknown default:
            permissionStatus = .denied
        }
    }

    private func startListening() {
        guard permissionStatus != .denied else { return }
        recognizedText = ""
        isListening = true
        voiceVM.startRecognition { text in
            recognizedText = text
        }
    }

    private func stopListening() {
        isListening = false
        voiceVM.stopRecognition()
    }

    private func sendToChat() {
        guard !recognizedText.isEmpty else { return }
        guard let conversation = environment.currentConversation else { return }
        let text = recognizedText
        recognizedText = ""
        Task {
            let updated = await environment.agentCore.run(userMessage: text, conversation: conversation)
            environment.currentConversation = updated
        }
        environment.selectedTab = .chat
    }
}

enum SpeechPermissionStatus {
    case notDetermined, microphoneNeeded, granted, denied
}

// MARK: - Voice ViewModel

@MainActor
final class VoiceViewModel: ObservableObject {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "fr-FR"))
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?

    func startRecognition(onUpdate: @escaping (String) -> Void) {
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else { return }

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            let inputNode = audioEngine.inputNode
            request = SFSpeechAudioBufferRecognitionRequest()
            guard let request = request else { return }
            request.shouldReportPartialResults = true

            recognitionTask = speechRecognizer.recognitionTask(with: request) { result, error in
                if let result = result {
                    let text = result.bestTranscription.formattedString
                    DispatchQueue.main.async {
                        onUpdate(text)
                    }
                }
                if error != nil {
                    DispatchQueue.main.async {
                        // Recognition ended (possibly due to silence timeout)
                    }
                }
            }

            let recordingFormat = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                request.append(buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            // Handle audio engine start error
        }
    }

    func stopRecognition() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
    }
}

// MARK: - Voice Animation

struct VoiceAnimationView: View {
    let isListening: Bool

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<5) { i in
                RoundedRectangle(cornerRadius: 3)
                    .fill(isListening ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 4, height: isListening ? CGFloat.random(in: 20...60) : 20)
                    .animation(
                        .easeInOut(duration: 0.3)
                        .repeatForever()
                        .delay(Double(i) * 0.1),
                        value: isListening
                    )
            }
        }
        .frame(height: 80)
    }
}
