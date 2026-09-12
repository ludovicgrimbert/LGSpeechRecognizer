//
//  PreviewSpeechRecognizer.swift
//  LGSpeechRecognizer
//

import Foundation

/// A recogniser with no microphone and no permission prompt: it "hears" a fixed text one
/// word at a time, with a human-ish delay, until the text runs out or ``stop()`` is called.
/// For SwiftUI previews and tests.
public actor PreviewSpeechRecognizer: SpeechRecognizer {

    public static let loremIpsum = """
        Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor \
        incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud \
        exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute \
        irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla \
        pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui \
        officia deserunt mollit anim id est laborum.
        """

    private let words: [String]
    private let wordDelay: Duration?
    private var isTranscribing = false
    private var generation = 0

    /// - Parameters:
    ///   - text: what gets "recognised", word by word.
    ///   - wordDelay: pause before each word; `nil` picks a random human-ish delay
    ///     (50 ms per letter + up to 200 ms). Pass a tiny fixed value in tests.
    public init(text: String = PreviewSpeechRecognizer.loremIpsum, wordDelay: Duration? = nil) {
        words = text.split(separator: " ").map(String.init)
        self.wordDelay = wordDelay
    }

    public func requestAuthorization() async -> SpeechAuthorizationStatus {
        .authorized
    }

    public func transcribe(_ configuration: SpeechRecognitionConfiguration) async -> AsyncThrowingStream<SpeechRecognitionResult, any Error> {
        isTranscribing = true
        generation += 1
        let currentGeneration = generation

        let (stream, continuation) = AsyncThrowingStream<SpeechRecognitionResult, any Error>.makeStream()
        let words = words
        let wordDelay = wordDelay

        let task = Task { [weak self] in
            var transcript = ""
            for word in words {
                try? await Task.sleep(for: wordDelay ?? .milliseconds(word.count * 50 + .random(in: 0...200)))
                guard !Task.isCancelled, let self, await self.isTranscribing(generation: currentGeneration) else { break }
                transcript += word + " "
                continuation.yield(SpeechRecognitionResult(
                    bestTranscription: Transcription(formattedString: transcript, segments: []),
                    isFinal: false,
                    transcriptions: []
                ))
            }
            continuation.finish()
        }
        continuation.onTermination = { _ in task.cancel() }
        return stream
    }

    public func stop() async {
        isTranscribing = false
    }

    private func isTranscribing(generation: Int) -> Bool {
        isTranscribing && generation == self.generation
    }
}
