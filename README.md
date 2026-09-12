# LGSpeechRecognizer

Live speech-to-text for iOS 17+ as a stream of value types, on top of Apple's Speech
framework. Swift 6, no dependencies.

```swift
.package(url: "https://github.com/ludovicgrimbert/LGSpeechRecognizer", exact: "0.3.1")
```

## Usage

```swift
import LGSpeechRecognizer

let recognizer: any SpeechRecognizer = LiveSpeechRecognizer()

let status = await recognizer.requestAuthorization()      // speech recognition + microphone
guard status.isAuthorized else { /* explain `status` */ return }

do {
    for try await result in await recognizer.transcribe() {
        text = result.bestTranscription.formattedString    // partial results as they come
    }
} catch let error as SpeechRecognitionError {
    show(error.localizedDescription)                        // user-presentable
}

await recognizer.stop()                                     // ends the stream, releases the mic
```

Tune it with a `SpeechRecognitionConfiguration`:

```swift
var configuration = SpeechRecognitionConfiguration()
configuration.locale = Locale(identifier: "fr-FR")          // default: the user's first preferred language
configuration.contextualStrings = ["Netflix", "Arte"]       // words to favour
configuration.requiresOnDeviceRecognition = true            // fails if the locale has no on-device model
configuration.audioSession = .managedByApp                  // default `.recording` configures + deactivates the shared session
for try await result in await recognizer.transcribe(configuration) { … }
```

`PreviewSpeechRecognizer()` "hears" a lorem ipsum word by word with no microphone or
prompt — for SwiftUI previews and tests. Your own fake is a conformance to
`SpeechRecognizer` (three methods).

### The app must declare

- `NSSpeechRecognitionUsageDescription`
- `NSMicrophoneUsageDescription`

`requestAuthorization()` asks for both; `transcribe` fails with
`SpeechRecognitionError.notAuthorized` rather than recording silence if either is missing.

### Behaviour worth knowing

- The stream **always ends**: on the final result, on `stop()`, when you stop iterating,
  or with an error. Starting a new `transcribe` ends the previous one.
- With `.recording`, the shared `AVAudioSession` is set to `.record` / `.measurement` /
  `.duckOthers` while transcribing and **deactivated afterwards**, so other audio in your
  app is only ducked during the dictation.
- Errors keep the system error they wrap (`underlyingError`) for logging.

## Migrating from 0.2 (`SpeechClient`)

`SpeechClient` still exists, deprecated, implemented over the protocol:

| 0.2 | 0.3 |
|---|---|
| `SpeechClient.liveValue` / `.previewValue` | `LiveSpeechRecognizer()` / `PreviewSpeechRecognizer()` as `any SpeechRecognizer` |
| `startTask(SFSpeechAudioBufferRecognitionRequest())` | `transcribe()` / `transcribe(SpeechRecognitionConfiguration(...))` |
| `finishTask()` | `stop()` |
| `requestAuthorization() -> SFSpeechRecognizerAuthorizationStatus` | `-> SpeechAuthorizationStatus` (adds `.microphoneDenied`, `.isAuthorized`) |
| `SpeechClient.Failure` | `SpeechRecognitionError` (`LocalizedError`, keeps the underlying error) |

## Example app

Open `LGSpeechRecognizer.xcworkspace`: the package next to `Example/LGSpeechRecognizerExample`, a
one-screen app built against the working tree — pick the live or the preview recogniser, tweak
the configuration, start/stop, watch the transcript, the authorization status and the errors.
Generated with [xcodegen](https://github.com/yonaskolb/XcodeGen) from `Example/project.yml`
(`cd Example && xcodegen generate` after adding files). The simulator has no microphone by
default: use the preview recogniser there, the live one on a device.

## Development

iOS-only package; build and test through a simulator (the workspace carries a shared
`LGSpeechRecognizer` scheme with the test action):

```sh
xcodebuild test -workspace LGSpeechRecognizer.xcworkspace -scheme LGSpeechRecognizer -destination 'platform=iOS Simulator,name=iPhone 17'
```
