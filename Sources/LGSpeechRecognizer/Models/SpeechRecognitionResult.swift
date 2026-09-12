//
//  SpeechRecognitionResult.swift
//  LGSpeechRecognizer
//
//  Created by Ludovic Grimbert on 24/12/2024.
//
//  The Speech framework's result types are reference types the app cannot construct, so
//  they are not testable or Sendable out of the box. These value types mirror them.
//

import Speech

/// One recognition result — partial (`isFinal == false`) or final.
public struct SpeechRecognitionResult: Equatable, Sendable {
    public var bestTranscription: Transcription
    public var isFinal: Bool
    public var speechRecognitionMetadata: SpeechRecognitionMetadata?
    public var transcriptions: [Transcription]

    public init(bestTranscription: Transcription,
                isFinal: Bool,
                speechRecognitionMetadata: SpeechRecognitionMetadata? = nil,
                transcriptions: [Transcription]) {
        self.bestTranscription = bestTranscription
        self.isFinal = isFinal
        self.speechRecognitionMetadata = speechRecognitionMetadata
        self.transcriptions = transcriptions
    }

    public init(_ result: SFSpeechRecognitionResult) {
        self.bestTranscription = Transcription(result.bestTranscription)
        self.isFinal = result.isFinal
        self.speechRecognitionMetadata = result.speechRecognitionMetadata.map(SpeechRecognitionMetadata.init)
        self.transcriptions = result.transcriptions.map(Transcription.init)
    }
}

/// Mirrors `SFSpeechRecognitionMetadata`.
public struct SpeechRecognitionMetadata: Equatable, Sendable {
    public var averagePauseDuration: TimeInterval
    public var speakingRate: Double
    public var voiceAnalytics: VoiceAnalytics?

    public init(averagePauseDuration: TimeInterval, speakingRate: Double, voiceAnalytics: VoiceAnalytics? = nil) {
        self.averagePauseDuration = averagePauseDuration
        self.speakingRate = speakingRate
        self.voiceAnalytics = voiceAnalytics
    }

    public init(_ metadata: SFSpeechRecognitionMetadata) {
        self.averagePauseDuration = metadata.averagePauseDuration
        self.speakingRate = metadata.speakingRate
        self.voiceAnalytics = metadata.voiceAnalytics.map(VoiceAnalytics.init)
    }
}
