//
//  SpeechRecognizerTests.swift
//  LGSpeechRecognizerTests
//
//  The live recogniser needs a microphone and permission prompts, so the tests cover what
//  can run headless: the preview recogniser, the fail-fast paths of the live one, the
//  configuration and error types, and the models.
//

import Speech
import Testing
@testable import LGSpeechRecognizer

@Suite("PreviewSpeechRecognizer")
struct PreviewSpeechRecognizerTests {

    @Test("is always authorised")
    func authorization() async {
        #expect(await PreviewSpeechRecognizer().requestAuthorization() == .authorized)
    }

    @Test("transcribes word by word and ends when the text runs out")
    func streamsToTheEnd() async throws {
        let recognizer = PreviewSpeechRecognizer(text: "un deux trois", wordDelay: .milliseconds(1))
        var transcripts: [String] = []
        for try await result in await recognizer.transcribe() {
            transcripts.append(result.bestTranscription.formattedString)
            #expect(result.isFinal == false)
        }
        #expect(transcripts == ["un ", "un deux ", "un deux trois "])
    }

    @Test("ends once stop() is called")
    func stopEndsTheStream() async throws {
        let recognizer = PreviewSpeechRecognizer(wordDelay: .milliseconds(1))
        var count = 0
        for try await _ in await recognizer.transcribe() {
            count += 1
            if count == 3 { await recognizer.stop() }
        }
        // Reaching here is the point: the loop must end after stop().
        #expect(count >= 3)
        #expect(count < 10)
    }

    @Test("a new transcription supersedes the previous one")
    func newTranscriptionSupersedes() async throws {
        let recognizer = PreviewSpeechRecognizer(text: "a b c d e f", wordDelay: .milliseconds(1))
        let first = await recognizer.transcribe()
        let second = await recognizer.transcribe()
        var firstCount = 0
        for try await _ in first { firstCount += 1 }
        var secondCount = 0
        for try await _ in second { secondCount += 1 }
        #expect(firstCount == 0)
        #expect(secondCount == 6)
    }
}

@Suite("LiveSpeechRecognizer")
struct LiveSpeechRecognizerTests {

    @Test("fails fast (and ends the stream) instead of hanging when not authorised")
    func notAuthorizedFailsFast() async {
        // Nothing in the test bundle ever requests speech authorisation, so it is undetermined.
        let recognizer = LiveSpeechRecognizer()
        var thrown: (any Error)?
        var received = 0
        do {
            for try await _ in await recognizer.transcribe() { received += 1 }
        } catch {
            thrown = error
        }
        #expect(received == 0)
        guard case .notAuthorized(let status)? = thrown as? SpeechRecognitionError else {
            Issue.record("Expected .notAuthorized, got \(String(describing: thrown))")
            return
        }
        #expect(status != .authorized)
        #expect(thrown?.localizedDescription.isEmpty == false)
    }

    @Test("stop() on an idle recogniser is harmless")
    func idleStop() async {
        let recognizer = LiveSpeechRecognizer()
        await recognizer.stop()
        await recognizer.stop()
    }
}

@Suite("Configuration and errors")
struct ConfigurationTests {

    @Test("defaults reproduce the historical behaviour")
    func defaults() {
        let configuration = SpeechRecognitionConfiguration()
        #expect(configuration.locale == SpeechRecognitionConfiguration.preferredLocale)
        #expect(configuration.reportsPartialResults == true)
        #expect(configuration.requiresOnDeviceRecognition == false)
        #expect(configuration.taskHint == .unspecified)
        #expect(configuration.contextualStrings.isEmpty)
        #expect(configuration.audioSession == .recording)
    }

    @Test("task hints map onto the Speech framework's")
    func taskHints() {
        #expect(SpeechRecognitionConfiguration.TaskHint.unspecified.sfValue == .unspecified)
        #expect(SpeechRecognitionConfiguration.TaskHint.dictation.sfValue == .dictation)
        #expect(SpeechRecognitionConfiguration.TaskHint.search.sfValue == .search)
        #expect(SpeechRecognitionConfiguration.TaskHint.confirmation.sfValue == .confirmation)
    }

    @Test("every error has a user-presentable description")
    func errorDescriptions() {
        struct Dummy: Error {}
        let errors: [SpeechRecognitionError] = [
            .notAuthorized(.denied), .notAuthorized(.microphoneDenied), .notAuthorized(.restricted), .notAuthorized(.notDetermined),
            .recognizerUnavailable(locale: Locale(identifier: "fr_FR")),
            .onDeviceRecognitionUnsupported(locale: Locale(identifier: "fr_FR")),
            .audioSessionFailed(underlying: Dummy()), .invalidInputFormat,
            .audioEngineFailed(underlying: Dummy()), .recognitionFailed(underlying: Dummy()),
        ]
        for error in errors {
            #expect(error.localizedDescription.isEmpty == false, "\(error)")
        }
        #expect(SpeechRecognitionError.audioEngineFailed(underlying: Dummy()).underlyingError is Dummy)
        #expect(SpeechRecognitionError.invalidInputFormat.underlyingError == nil)
    }
}

@Suite("Models")
struct ModelTests {

    @Test("value types compare structurally")
    func valueSemantics() {
        let segment = TranscriptionSegment(alternativeSubstrings: ["hallo"], confidence: 0.9, duration: 0.5, substring: "hello", timestamp: 1)
        let a = SpeechRecognitionResult(
            bestTranscription: Transcription(formattedString: "hello", segments: [segment]),
            isFinal: false,
            transcriptions: []
        )
        var b = a
        #expect(a == b)
        b.isFinal = true
        #expect(a != b)
    }
}
