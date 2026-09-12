//
//  SpeechRecognizer.swift
//  LGSpeechRecognizer
//

import Foundation
import Speech

/// Live speech-to-text as a stream of results.
///
/// Two implementations ship with the package: ``LiveSpeechRecognizer`` (the microphone and
/// Apple's `SFSpeechRecognizer`) and ``PreviewSpeechRecognizer`` (a fake for SwiftUI previews
/// and tests). Apps hold one as `any SpeechRecognizer` and swap it in tests.
///
/// ```swift
/// let recognizer: any SpeechRecognizer = LiveSpeechRecognizer()
/// guard await recognizer.requestAuthorization().isAuthorized else { return }
/// for try await result in await recognizer.transcribe() {
///     text = result.bestTranscription.formattedString
/// }
/// ```
public protocol SpeechRecognizer: Sendable {
    /// Asks for the permissions transcription needs (speech recognition *and* the microphone),
    /// or reports the current status without prompting when already decided.
    func requestAuthorization() async -> SpeechAuthorizationStatus

    /// Starts transcribing the microphone. The stream yields every result (partial ones too
    /// when `configuration.reportsPartialResults`) and ends when the recogniser delivers a
    /// final result, when ``stop()`` is called, when the consumer stops iterating, or with a
    /// ``SpeechRecognitionError`` when something fails — it never hangs.
    ///
    /// Starting a new transcription ends the previous one.
    func transcribe(_ configuration: SpeechRecognitionConfiguration) async -> AsyncThrowingStream<SpeechRecognitionResult, any Error>

    /// Ends the current transcription: the stream finishes, the microphone is released.
    func stop() async
}

public extension SpeechRecognizer {
    /// ``transcribe(_:)`` with the default ``SpeechRecognitionConfiguration``.
    func transcribe() async -> AsyncThrowingStream<SpeechRecognitionResult, any Error> {
        await transcribe(SpeechRecognitionConfiguration())
    }
}

// MARK: - Authorization

/// The combined speech-recognition + microphone permission state.
public enum SpeechAuthorizationStatus: Sendable, Equatable {
    /// Neither permission has been asked yet.
    case notDetermined
    /// The user refused speech recognition.
    case denied
    /// Speech recognition is not allowed on this device (parental controls, MDM…).
    case restricted
    /// Speech recognition is allowed but the user refused the microphone.
    case microphoneDenied
    /// Both permissions granted.
    case authorized

    public var isAuthorized: Bool { self == .authorized }

    init(_ status: SFSpeechRecognizerAuthorizationStatus) {
        switch status {
        case .authorized: self = .authorized
        case .denied: self = .denied
        case .restricted: self = .restricted
        case .notDetermined: self = .notDetermined
        @unknown default: self = .notDetermined
        }
    }
}

// MARK: - Configuration

/// What to recognise and how. Every field has the default the package used before it was
/// configurable, so `SpeechRecognitionConfiguration()` behaves like the historical client.
public struct SpeechRecognitionConfiguration: Sendable, Equatable {

    /// Mirrors `SFSpeechRecognitionTaskHint`.
    public enum TaskHint: Sendable, Equatable {
        case unspecified, dictation, search, confirmation

        var sfValue: SFSpeechRecognitionTaskHint {
            switch self {
            case .unspecified: .unspecified
            case .dictation: .dictation
            case .search: .search
            case .confirmation: .confirmation
            }
        }
    }

    /// Who configures the shared `AVAudioSession`.
    public enum AudioSessionPolicy: Sendable, Equatable {
        /// The recogniser sets the session up for recording (`.record`, `.measurement`,
        /// `.duckOthers`) when transcription starts and **deactivates it when it stops**, so
        /// the rest of the app's audio is no longer ducked afterwards.
        case recording
        /// The app owns the session; the recogniser only reads the microphone.
        case managedByApp
    }

    /// Language to recognise. Defaults to the user's first preferred language.
    public var locale: Locale
    /// Yield intermediate results as words are recognised (`true`), or only the final one.
    public var reportsPartialResults: Bool
    /// Fail rather than send audio to Apple's servers. Not every locale supports it.
    public var requiresOnDeviceRecognition: Bool
    public var taskHint: TaskHint
    /// Words the recogniser should favour (names, commands…).
    public var contextualStrings: [String]
    public var audioSession: AudioSessionPolicy

    /// The user's first preferred language, which is what speech recognition should follow
    /// (`Locale.current` reflects the region format and can differ).
    public static var preferredLocale: Locale {
        Locale(identifier: Locale.preferredLanguages.first ?? Locale.current.identifier)
    }

    public init(locale: Locale = SpeechRecognitionConfiguration.preferredLocale,
                reportsPartialResults: Bool = true,
                requiresOnDeviceRecognition: Bool = false,
                taskHint: TaskHint = .unspecified,
                contextualStrings: [String] = [],
                audioSession: AudioSessionPolicy = .recording) {
        self.locale = locale
        self.reportsPartialResults = reportsPartialResults
        self.requiresOnDeviceRecognition = requiresOnDeviceRecognition
        self.taskHint = taskHint
        self.contextualStrings = contextualStrings
        self.audioSession = audioSession
    }

    /// Reads the options an app used to set on the request it handed to the legacy
    /// `SpeechClient.startTask`.
    init(_ request: SFSpeechAudioBufferRecognitionRequest) {
        self.init(reportsPartialResults: request.shouldReportPartialResults,
                  requiresOnDeviceRecognition: request.requiresOnDeviceRecognition,
                  taskHint: TaskHint(request.taskHint),
                  contextualStrings: request.contextualStrings)
    }
}

extension SpeechRecognitionConfiguration.TaskHint {
    init(_ hint: SFSpeechRecognitionTaskHint) {
        switch hint {
        case .dictation: self = .dictation
        case .search: self = .search
        case .confirmation: self = .confirmation
        case .unspecified: self = .unspecified
        @unknown default: self = .unspecified
        }
    }
}
