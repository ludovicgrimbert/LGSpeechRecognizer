//
//  VoiceAnalytics.swift
//  LGSpeechRecognizer
//
//  Created by Ludovic Grimbert on 24/12/2024.
//

import Speech

/// Mirrors `SFVoiceAnalytics`.
public struct VoiceAnalytics: Equatable, Sendable {
    public var jitter: AcousticFeature
    public var pitch: AcousticFeature
    public var shimmer: AcousticFeature
    public var voicing: AcousticFeature

    public init(jitter: AcousticFeature, pitch: AcousticFeature, shimmer: AcousticFeature, voicing: AcousticFeature) {
        self.jitter = jitter
        self.pitch = pitch
        self.shimmer = shimmer
        self.voicing = voicing
    }

    public init(_ analytics: SFVoiceAnalytics) {
        self.jitter = AcousticFeature(analytics.jitter)
        self.pitch = AcousticFeature(analytics.pitch)
        self.shimmer = AcousticFeature(analytics.shimmer)
        self.voicing = AcousticFeature(analytics.voicing)
    }
}

/// Mirrors `SFAcousticFeature`.
public struct AcousticFeature: Equatable, Sendable {
    public var acousticFeatureValuePerFrame: [Double]
    public var frameDuration: TimeInterval

    public init(acousticFeatureValuePerFrame: [Double], frameDuration: TimeInterval) {
        self.acousticFeatureValuePerFrame = acousticFeatureValuePerFrame
        self.frameDuration = frameDuration
    }

    public init(_ feature: SFAcousticFeature) {
        self.acousticFeatureValuePerFrame = feature.acousticFeatureValuePerFrame
        self.frameDuration = feature.frameDuration
    }
}
