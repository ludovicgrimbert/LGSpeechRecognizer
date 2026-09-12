//
//  SpeechClient.swift
//  LGSpeechRecognizer
//
//  Created by Ludovic Grimbert on 24/12/2024.
//

import Speech

/// The 0.1/0.2 API, kept for one release as a thin layer over ``SpeechRecognizer``.
///
/// Migration: hold `any SpeechRecognizer` (`LiveSpeechRecognizer()` / `PreviewSpeechRecognizer()`)
/// instead of `SpeechClient.liveValue` / `.previewValue`; `startTask(request)` becomes
/// `transcribe(configuration)` (the request's options map to ``SpeechRecognitionConfiguration``);
/// `finishTask()` becomes `stop()`; `requestAuthorization()` returns ``SpeechAuthorizationStatus``
/// (which now covers the microphone); errors are ``SpeechRecognitionError`` instead of `Failure`.
@available(*, deprecated, message: "Use the SpeechRecognizer protocol: LiveSpeechRecognizer() or PreviewSpeechRecognizer()")
public struct SpeechClient: Sendable {
    public var finishTask: @Sendable () async -> Void
    public var requestAuthorization: @Sendable () async -> SFSpeechRecognizerAuthorizationStatus
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

    /// Wraps any ``SpeechRecognizer`` in the legacy shape.
    public init(recognizer: any SpeechRecognizer) {
        finishTask = { await recognizer.stop() }
        requestAuthorization = {
            switch await recognizer.requestAuthorization() {
            case .authorized: .authorized
            case .denied, .microphoneDenied: .denied
            case .restricted: .restricted
            case .notDetermined: .notDetermined
            }
        }
        startTask = { request in
            let upstream = await recognizer.transcribe(SpeechRecognitionConfiguration(request))
            return AsyncThrowingStream { continuation in
                let task = Task {
                    do {
                        for try await result in upstream {
                            continuation.yield(result)
                        }
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: Failure(error))
                    }
                }
                continuation.onTermination = { _ in task.cancel() }
            }
        }
    }

    public static var liveValue: Self { Self(recognizer: LiveSpeechRecognizer()) }
    public static var previewValue: Self { Self(recognizer: PreviewSpeechRecognizer()) }

    public enum Failure: Error, Equatable {
        case taskError
        case couldntStartAudioEngine
        case couldntConfigureAudioSession

        init(_ error: any Error) {
            switch error as? SpeechRecognitionError {
            case .audioSessionFailed: self = .couldntConfigureAudioSession
            case .audioEngineFailed, .invalidInputFormat: self = .couldntStartAudioEngine
            default: self = .taskError
            }
        }
    }
}
