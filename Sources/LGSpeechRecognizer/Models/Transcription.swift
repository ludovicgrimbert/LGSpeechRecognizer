//
//  Transcription.swift
//  LGSpeechRecognizer
//
//  Created by Ludovic Grimbert on 24/12/2024.
//

import Speech

/// Mirrors `SFTranscription`.
public struct Transcription: Equatable, Sendable {
    public var formattedString: String
    public var segments: [TranscriptionSegment]

    public init(formattedString: String, segments: [TranscriptionSegment]) {
        self.formattedString = formattedString
        self.segments = segments
    }

    public init(_ transcription: SFTranscription) {
        self.formattedString = transcription.formattedString
        self.segments = transcription.segments.map(TranscriptionSegment.init)
    }
}

/// Mirrors `SFTranscriptionSegment`.
public struct TranscriptionSegment: Equatable, Sendable {
    public var alternativeSubstrings: [String]
    public var confidence: Float
    public var duration: TimeInterval
    public var substring: String
    public var timestamp: TimeInterval

    public init(alternativeSubstrings: [String], confidence: Float, duration: TimeInterval, substring: String, timestamp: TimeInterval) {
        self.alternativeSubstrings = alternativeSubstrings
        self.confidence = confidence
        self.duration = duration
        self.substring = substring
        self.timestamp = timestamp
    }

    public init(_ segment: SFTranscriptionSegment) {
        self.alternativeSubstrings = segment.alternativeSubstrings
        self.confidence = segment.confidence
        self.duration = segment.duration
        self.substring = segment.substring
        self.timestamp = segment.timestamp
    }
}
