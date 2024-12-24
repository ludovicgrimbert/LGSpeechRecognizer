//
//  Model.swift
//  LGSpeechRecognizer
//
//  Created by Ludovic Grimbert on 24/12/2024.
//


import ComposableArchitecture
import Speech

//************************** MODEL ******************

// The core data types in the Speech framework are reference types and are not constructible by us,
// and so they aren't testable out the box. We define struct versions of those types to make
// them easier to use and test.

public struct SpeechRecognitionMetadata: Equatable, Sendable {
    var averagePauseDuration: TimeInterval
    var speakingRate: Double
    var voiceAnalytics: VoiceAnalytics?
}

public struct SpeechRecognitionResult: Equatable, Sendable {
    var bestTranscription: Transcription
    var isFinal: Bool
    var speechRecognitionMetadata: SpeechRecognitionMetadata?
    var transcriptions: [Transcription]
}

public struct Transcription: Equatable, Sendable {
    var formattedString: String
//    var segments: [TranscriptionSegment]
}

public struct TranscriptionSegment: Equatable, Sendable {
    var alternativeSubstrings: [String]
    var confidence: Float
    var duration: TimeInterval
    var substring: String
    var timestamp: TimeInterval
}

public struct VoiceAnalytics: Equatable, Sendable {
    var jitter: AcousticFeature
    var pitch: AcousticFeature
    var shimmer: AcousticFeature
    var voicing: AcousticFeature
}

public struct AcousticFeature: Equatable, Sendable {
    var acousticFeatureValuePerFrame: [Double]
    var frameDuration: TimeInterval
}

public extension SpeechRecognitionMetadata {
    public init(_ speechRecognitionMetadata: SFSpeechRecognitionMetadata) {
        self.averagePauseDuration = speechRecognitionMetadata.averagePauseDuration
        self.speakingRate = speechRecognitionMetadata.speakingRate
        self.voiceAnalytics = speechRecognitionMetadata.voiceAnalytics.map(VoiceAnalytics.init)
    }
}

public extension SpeechRecognitionResult {
    public init(_ speechRecognitionResult: SFSpeechRecognitionResult) {
        self.bestTranscription = Transcription(speechRecognitionResult.bestTranscription)
        self.isFinal = speechRecognitionResult.isFinal
        self.speechRecognitionMetadata = speechRecognitionResult.speechRecognitionMetadata
            .map(SpeechRecognitionMetadata.init)
        self.transcriptions = speechRecognitionResult.transcriptions.map(Transcription.init)
    }
}

public extension Transcription{
    public init(_ transcription: SFTranscription) {
        self.formattedString = transcription.formattedString
//        self.segments = transcription.segments.map(TranscriptionSegment.init)
    }
}

public extension TranscriptionSegment {
    public init(_ transcriptionSegment: SFTranscriptionSegment) {
        self.alternativeSubstrings = transcriptionSegment.alternativeSubstrings
        self.confidence = transcriptionSegment.confidence
        self.duration = transcriptionSegment.duration
        self.substring = transcriptionSegment.substring
        self.timestamp = transcriptionSegment.timestamp
    }
}

public extension VoiceAnalytics {
    public init(_ voiceAnalytics: SFVoiceAnalytics) {
        self.jitter = AcousticFeature(voiceAnalytics.jitter)
        self.pitch = AcousticFeature(voiceAnalytics.pitch)
        self.shimmer = AcousticFeature(voiceAnalytics.shimmer)
        self.voicing = AcousticFeature(voiceAnalytics.voicing)
    }
}

public extension AcousticFeature {
    public init(_ acousticFeature: SFAcousticFeature) {
        self.acousticFeatureValuePerFrame = acousticFeature.acousticFeatureValuePerFrame
        self.frameDuration = acousticFeature.frameDuration
    }
}
