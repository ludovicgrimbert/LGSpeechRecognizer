//
//  LiveSpeechRecognizer.swift
//  LGSpeechRecognizer
//
//  Created by Ludovic Grimbert on 24/12/2024.
//

import AVFoundation
import Speech

/// The real recogniser: an `AVAudioEngine` tap on the microphone feeding
/// `SFSpeechRecognizer`. One transcription at a time; all state lives on the actor.
public actor LiveSpeechRecognizer: SpeechRecognizer {

    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine?
    private var continuation: AsyncThrowingStream<SpeechRecognitionResult, any Error>.Continuation?
    private var audioSessionPolicy: SpeechRecognitionConfiguration.AudioSessionPolicy = .managedByApp
    /// Identifies the current transcription so a stale stream's termination cannot tear
    /// down the one that replaced it.
    private var generation = 0

    public init() {}

    // MARK: SpeechRecognizer

    public func requestAuthorization() async -> SpeechAuthorizationStatus {
        let speechStatus = await withCheckedContinuation { (continuation: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        let status = SpeechAuthorizationStatus(speechStatus)
        guard status == .authorized else { return status }
        // The historical client never asked for this one, so iOS prompted in the middle of
        // the first transcription — and a refusal left the engine recording silence.
        return await AVAudioApplication.requestRecordPermission() ? .authorized : .microphoneDenied
    }

    public func transcribe(_ configuration: SpeechRecognitionConfiguration) async -> AsyncThrowingStream<SpeechRecognitionResult, any Error> {
        tearDown()
        generation += 1
        let currentGeneration = generation

        let (stream, continuation) = AsyncThrowingStream<SpeechRecognitionResult, any Error>.makeStream()
        self.continuation = continuation
        continuation.onTermination = { [weak self] _ in
            Task { await self?.tearDown(ifGeneration: currentGeneration) }
        }

        do {
            try begin(configuration)
        } catch {
            continuation.finish(throwing: error)
            tearDown()
        }
        return stream
    }

    public func stop() async {
        tearDown()
    }

    // MARK: Starting

    private func begin(_ configuration: SpeechRecognitionConfiguration) throws {
        let speechStatus = SpeechAuthorizationStatus(SFSpeechRecognizer.authorizationStatus())
        guard speechStatus == .authorized else {
            throw SpeechRecognitionError.notAuthorized(speechStatus)
        }
        guard AVAudioApplication.shared.recordPermission == .granted else {
            throw SpeechRecognitionError.notAuthorized(.microphoneDenied)
        }

        guard let recognizer = SFSpeechRecognizer(locale: configuration.locale), recognizer.isAvailable else {
            throw SpeechRecognitionError.recognizerUnavailable(locale: configuration.locale)
        }
        if configuration.requiresOnDeviceRecognition, !recognizer.supportsOnDeviceRecognition {
            throw SpeechRecognitionError.onDeviceRecognitionUnsupported(locale: configuration.locale)
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = configuration.reportsPartialResults
        request.requiresOnDeviceRecognition = configuration.requiresOnDeviceRecognition
        request.taskHint = configuration.taskHint.sfValue
        request.contextualStrings = configuration.contextualStrings

        if configuration.audioSession == .recording {
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.record, mode: .measurement, options: .duckOthers)
                try session.setActive(true, options: .notifyOthersOnDeactivation)
            } catch {
                throw SpeechRecognitionError.audioSessionFailed(underlying: error)
            }
        }
        audioSessionPolicy = configuration.audioSession

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        // Installing a tap with a 0 Hz / 0-channel format is a fatal AVAudioEngine assertion.
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw SpeechRecognitionError.invalidInputFormat
        }

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            // Convert on the framework's queue: the SF classes are not Sendable, the structs are.
            let converted = result.map(SpeechRecognitionResult.init)
            Task { await self?.handle(result: converted, error: error) }
        }
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
        engine.prepare()
        do {
            try engine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            throw SpeechRecognitionError.audioEngineFailed(underlying: error)
        }

        self.recognizer = recognizer
        self.request = request
        self.audioEngine = engine
    }

    // MARK: Results

    private func handle(result: SpeechRecognitionResult?, error: (any Error)?) {
        guard let continuation else { return }
        switch (result, error) {
        case let (.some(result), _):
            continuation.yield(result)
            if result.isFinal {
                tearDown()
            }
        case let (nil, .some(error)):
            continuation.finish(throwing: SpeechRecognitionError.recognitionFailed(underlying: error))
            tearDown()
        case (nil, nil):
            // Documented as impossible by the framework; ending the stream beats crashing the host app.
            tearDown()
        }
    }

    // MARK: Stopping

    private func tearDown(ifGeneration expected: Int? = nil) {
        if let expected, expected != generation { return }

        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil
        request?.endAudio()
        request = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        recognizer = nil
        continuation?.finish()
        continuation = nil

        if audioSessionPolicy == .recording {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            audioSessionPolicy = .managedByApp
        }
    }
}
