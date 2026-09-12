//
//  LGSpeechRecognizerExampleApp.swift
//  LGSpeechRecognizerExample
//
//  Live transcription with LGSpeechRecognizer. Switch to the preview recogniser to try the
//  flow without a microphone (the simulator has none by default).
//

import SwiftUI

@main
struct LGSpeechRecognizerExampleApp: App {
    var body: some Scene {
        WindowGroup {
            TranscriptionView()
        }
    }
}
