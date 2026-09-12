//
//  TranscriptionModel.swift
//  LGSpeechRecognizerExample
//

import Foundation
import Observation
import LGSpeechRecognizer

/// Drives one recogniser at a time and exposes what the screen shows.
@Observable
@MainActor
final class TranscriptionModel {

    enum Source: String, CaseIterable, Identifiable {
        case live = "Live"
        case preview = "Preview"
        var id: String { rawValue }
    }

    // Settings
    var source: Source = .preview
    var reportsPartialResults = true
    var requiresOnDeviceRecognition = false
    var contextualStrings = ""

    // State
    private(set) var authorization: SpeechAuthorizationStatus?
    private(set) var isTranscribing = false
    private(set) var transcript = ""
    private(set) var isFinal = false
    private(set) var errorMessage: String?

    @ObservationIgnored private var recognizer: (any SpeechRecognizer)?
    @ObservationIgnored private var task: Task<Void, Never>?

    var configuration: SpeechRecognitionConfiguration {
        var configuration = SpeechRecognitionConfiguration()
        configuration.reportsPartialResults = reportsPartialResults
        configuration.requiresOnDeviceRecognition = requiresOnDeviceRecognition
        configuration.contextualStrings = contextualStrings
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return configuration
    }

    func toggle() {
        if isTranscribing { stop() } else { start() }
    }

    func start() {
        task?.cancel()
        errorMessage = nil
        transcript = ""
        isFinal = false

        let recognizer: any SpeechRecognizer = source == .live ? LiveSpeechRecognizer() : PreviewSpeechRecognizer()
        self.recognizer = recognizer
        let configuration = configuration

        task = Task {
            let status = await recognizer.requestAuthorization()
            authorization = status
            guard status.isAuthorized else { return }

            isTranscribing = true
            defer { isTranscribing = false }
            do {
                for try await result in await recognizer.transcribe(configuration) {
                    transcript = result.bestTranscription.formattedString
                    isFinal = result.isFinal
                }
            } catch {
                // SpeechRecognitionError is a LocalizedError: its description is user-presentable.
                errorMessage = error.localizedDescription
            }
        }
    }

    func stop() {
        guard let recognizer else { return }
        Task { await recognizer.stop() }
    }
}
