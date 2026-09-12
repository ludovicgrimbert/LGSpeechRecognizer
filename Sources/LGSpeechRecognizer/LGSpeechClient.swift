//
//  LGSpeechClient.swift
//  LGSpeechRecognizer
//
//  Created by Ludovic Grimbert on 24/12/2024.
//

import Speech

/// Speech recognition as three async operations, so an app can hold the live
/// implementation or hand-roll a fake for previews and tests.
///
/// ```swift
/// let speech = SpeechClient.liveValue
/// guard await speech.requestAuthorization() == .authorized else { return }
/// for try await result in await speech.startTask(SFSpeechAudioBufferRecognitionRequest()) {
///     print(result.bestTranscription.formattedString)
/// }
/// ```
public struct SpeechClient: Sendable {
    /// Stops the current recognition task and releases the audio engine.
    public var finishTask: @Sendable () async -> Void
    /// Asks the user for speech-recognition permission (or returns the current status).
    public var requestAuthorization: @Sendable () async -> SFSpeechRecognizerAuthorizationStatus
    /// Starts recognising the microphone into `request`; the stream yields every partial
    /// result until `finishTask()` is called or the framework ends the task.
    public var startTask:
        @Sendable (_ request: SFSpeechAudioBufferRecognitionRequest) async -> AsyncThrowingStream<
            SpeechRecognitionResult, Error
        >

    public init(
        finishTask: @escaping @Sendable () async -> Void,
        requestAuthorization: @escaping @Sendable () async -> SFSpeechRecognizerAuthorizationStatus,
        startTask: @escaping @Sendable (_ request: SFSpeechAudioBufferRecognitionRequest) async -> AsyncThrowingStream<
            SpeechRecognitionResult, Error
        >
    ) {
        self.finishTask = finishTask
        self.requestAuthorization = requestAuthorization
        self.startTask = startTask
    }

    public enum Failure: Error, Equatable {
        case taskError
        case couldntStartAudioEngine
        case couldntConfigureAudioSession
    }
}

// MARK: - Live

public extension SpeechClient {
    /// The real thing: `SFSpeechRecognizer` fed by an `AVAudioEngine` tap. Each access
    /// creates its own recogniser; hold on to one instance.
    static var liveValue: Self {
        let speech = Speech()
        return Self(
            finishTask: {
                await speech.finishTask()
            },
            requestAuthorization: {
                await withCheckedContinuation { continuation in
                    SFSpeechRecognizer.requestAuthorization { status in
                        continuation.resume(returning: status)
                    }
                }
            },
            startTask: { request in
                let request = UncheckedSendable(request)
                return await speech.startTask(request: request)
            }
        )
    }
}

// MARK: - Preview

public extension SpeechClient {
    /// No microphone, no permission prompt: "transcribes" a lorem ipsum word by word, with a
    /// human-ish delay, until `finishTask()` is called (which also ends the stream).
    static var previewValue: Self {
        let isRecording = LockIsolated(false)

        return Self(
            finishTask: { isRecording.setValue(false) },
            requestAuthorization: { .authorized },
            startTask: { _ in
                AsyncThrowingStream { continuation in
                    let task = Task {
                        isRecording.setValue(true)
                        var finalText = """
                        Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor \
                        incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud \
                        exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute \
                        irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla \
                        pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui \
                        officia deserunt mollit anim id est laborum.
                        """
                        var text = ""
                        while isRecording.value, !finalText.isEmpty, !Task.isCancelled {
                            let word = finalText.prefix { $0 != " " }
                            try? await Task.sleep(for: .milliseconds(word.count * 50 + .random(in: 0...200)))
                            finalText.removeFirst(word.count)
                            if finalText.first == " " {
                                finalText.removeFirst()
                            }
                            text += word + " "
                            continuation.yield(
                                SpeechRecognitionResult(
                                    bestTranscription: Transcription(
                                        formattedString: text,
                                        segments: []
                                    ),
                                    isFinal: false,
                                    transcriptions: []
                                )
                            )
                        }
                        // The stream used to stay open forever here; consumers iterating it
                        // never got out of their `for await`.
                        continuation.finish()
                    }
                    continuation.onTermination = { _ in
                        isRecording.setValue(false)
                        task.cancel()
                    }
                }
            }
        )
    }
}
