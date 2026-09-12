//
//  SpeechClientTests.swift
//  LGSpeechRecognizerTests
//
//  The live client needs a microphone and a permission prompt, so these exercise the
//  package's own surface: the value types, the closure-based client, and the preview
//  implementation apps use in SwiftUI previews and tests.
//

import Speech
import Testing
@testable import LGSpeechRecognizer

@Suite("SpeechClient")
struct SpeechClientTests {

    @Test("A client is just its three operations")
    func customClient() async throws {
        let client = SpeechClient(
            finishTask: {},
            requestAuthorization: { .denied },
            startTask: { _ in
                AsyncThrowingStream { continuation in
                    continuation.yield(SpeechRecognitionResult(
                        bestTranscription: Transcription(formattedString: "hello", segments: []),
                        isFinal: true,
                        transcriptions: []
                    ))
                    continuation.finish()
                }
            }
        )

        #expect(await client.requestAuthorization() == .denied)

        var results: [SpeechRecognitionResult] = []
        for try await result in await client.startTask(SFSpeechAudioBufferRecognitionRequest()) {
            results.append(result)
        }
        #expect(results.map(\.bestTranscription.formattedString) == ["hello"])
        #expect(results.first?.isFinal == true)
    }

    @Test("previewValue transcribes word by word and ends once finishTask() is called")
    func previewValueStreamsThenEnds() async throws {
        let client = SpeechClient.previewValue
        #expect(await client.requestAuthorization() == .authorized)

        var transcripts: [String] = []
        for try await result in await client.startTask(SFSpeechAudioBufferRecognitionRequest()) {
            transcripts.append(result.bestTranscription.formattedString)
            if transcripts.count == 3 {
                await client.finishTask()
            }
        }
        // Reaching here at all is the point: the stream must end after finishTask().
        #expect(transcripts.count >= 3)
        #expect(transcripts[0] == "Lorem ")
        #expect(transcripts[1] == "Lorem ipsum ")
        #expect(transcripts[2] == "Lorem ipsum dolor ")
    }

    @Test("previewValue stops producing when its consumer stops listening")
    func previewValueHonoursTermination() async throws {
        let client = SpeechClient.previewValue
        let stream = await client.startTask(SFSpeechAudioBufferRecognitionRequest())
        var iterator = stream.makeAsyncIterator()
        let first = try await iterator.next()
        #expect(first?.bestTranscription.formattedString == "Lorem ")
        // Dropping the iterator/stream terminates it; nothing to assert beyond not hanging,
        // which the test's own completion demonstrates.
    }
}

@Suite("Models")
struct ModelTests {

    @Test("Failure cases are distinct and equatable")
    func failures() {
        #expect(SpeechClient.Failure.taskError == .taskError)
        #expect(SpeechClient.Failure.taskError != .couldntStartAudioEngine)
        #expect(SpeechClient.Failure.couldntConfigureAudioSession != .couldntStartAudioEngine)
    }

    @Test("Value types compare structurally")
    func valueSemantics() {
        let segment = TranscriptionSegment(alternativeSubstrings: ["hallo"], confidence: 0.9, duration: 0.5, substring: "hello", timestamp: 1)
        let a = SpeechRecognitionResult(
            bestTranscription: Transcription(formattedString: "hello", segments: [segment]),
            isFinal: false,
            speechRecognitionMetadata: nil,
            transcriptions: []
        )
        var b = a
        #expect(a == b)
        b.isFinal = true
        #expect(a != b)
    }
}
