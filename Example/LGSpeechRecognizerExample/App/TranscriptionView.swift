//
//  TranscriptionView.swift
//  LGSpeechRecognizerExample
//

import SwiftUI
import LGSpeechRecognizer

struct TranscriptionView: View {
    @State private var model = TranscriptionModel()

    var body: some View {
        NavigationStack {
            Form {
                Section("Recognizer") {
                    Picker("Source", selection: $model.source) {
                        ForEach(TranscriptionModel.Source.allCases) { source in
                            Text(source.rawValue).tag(source)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(model.isTranscribing)
                    Text(model.source == .live
                         ? "Microphone + SFSpeechRecognizer. Asks for speech recognition and microphone permissions."
                         : "No microphone, no prompt: a lorem ipsum arrives word by word.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Configuration") {
                    Toggle("Partial results", isOn: $model.reportsPartialResults)
                    Toggle("On-device only", isOn: $model.requiresOnDeviceRecognition)
                    TextField("Contextual strings, comma-separated", text: $model.contextualStrings)
                        .textInputAutocapitalization(.never)
                }
                .disabled(model.isTranscribing)

                Section("Transcript") {
                    Text(model.transcript.isEmpty ? "—" : model.transcript)
                        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
                        .foregroundStyle(model.transcript.isEmpty ? .secondary : .primary)
                    if model.isFinal {
                        Label("Final result", systemImage: "checkmark.circle").font(.footnote).foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button {
                        model.toggle()
                    } label: {
                        Label(model.isTranscribing ? "Stop" : "Start transcribing",
                              systemImage: model.isTranscribing ? "stop.circle.fill" : "mic.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(model.isTranscribing ? .red : .accentColor)

                    if let authorization = model.authorization {
                        LabeledContent("Authorization", value: describe(authorization))
                            .font(.footnote)
                    }
                    if let errorMessage = model.errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("LGSpeechRecognizer")
        }
    }

    private func describe(_ status: SpeechAuthorizationStatus) -> String {
        switch status {
        case .authorized: "speech + microphone granted"
        case .microphoneDenied: "microphone denied"
        case .denied: "speech recognition denied"
        case .restricted: "restricted on this device"
        case .notDetermined: "not determined"
        }
    }
}
