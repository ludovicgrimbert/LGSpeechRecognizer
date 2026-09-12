//
//  SpeechRecognitionError.swift
//  LGSpeechRecognizer
//

import Foundation

/// Everything ``LiveSpeechRecognizer`` can fail with. Thrown through the transcription
/// stream; `localizedDescription` is user-presentable, and the cases that wrap a system
/// error keep it for diagnostics.
public enum SpeechRecognitionError: Error, LocalizedError, Sendable {
    /// Speech recognition or the microphone is not authorised. Call
    /// `requestAuthorization()` first.
    case notAuthorized(SpeechAuthorizationStatus)
    /// `SFSpeechRecognizer` could not be created for the locale, or reports itself
    /// unavailable (no network for server-based recognition, model not ready…).
    case recognizerUnavailable(locale: Locale)
    /// `requiresOnDeviceRecognition` was set but this locale has no on-device model.
    case onDeviceRecognitionUnsupported(locale: Locale)
    /// The shared `AVAudioSession` refused the recording configuration.
    case audioSessionFailed(underlying: any Error)
    /// The microphone input has no usable format (no microphone, permission refused, some
    /// simulators). Starting the engine anyway is a hard crash, so it is reported instead.
    case invalidInputFormat
    /// `AVAudioEngine.start()` failed.
    case audioEngineFailed(underlying: any Error)
    /// The recognition task reported an error.
    case recognitionFailed(underlying: any Error)

    public var errorDescription: String? {
        switch self {
        case .notAuthorized(let status):
            switch status {
            case .microphoneDenied: "Microphone access was denied."
            case .restricted: "Speech recognition is not allowed on this device."
            case .denied: "Speech recognition access was denied."
            case .notDetermined, .authorized: "Speech recognition has not been authorised yet."
            }
        case .recognizerUnavailable(let locale):
            "Speech recognition is not available for \(locale.identifier) right now."
        case .onDeviceRecognitionUnsupported(let locale):
            "On-device speech recognition is not available for \(locale.identifier)."
        case .audioSessionFailed:
            "The audio session could not be configured for recording."
        case .invalidInputFormat:
            "No usable microphone input was found."
        case .audioEngineFailed:
            "The audio engine could not be started."
        case .recognitionFailed(let underlying):
            "Speech recognition failed: \(underlying.localizedDescription)"
        }
    }

    /// The system error this wraps, when there is one.
    public var underlyingError: (any Error)? {
        switch self {
        case .audioSessionFailed(let error), .audioEngineFailed(let error), .recognitionFailed(let error):
            error
        default:
            nil
        }
    }
}
