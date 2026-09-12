# Changelog

All notable changes to this package. [Keep a Changelog](https://keepachangelog.com) format,
[SemVer](https://semver.org) — on `0.x`, minor versions may break source compatibility.

## [0.3.0] - 2026-09-12

### Added
- `SpeechRecognizer` protocol with two implementations, `LiveSpeechRecognizer` (actor) and
  `PreviewSpeechRecognizer`; `SpeechRecognitionConfiguration` (locale, partial results,
  on-device, task hint, contextual strings, audio-session policy); `SpeechAuthorizationStatus`
  (covers the microphone too); `SpeechRecognitionError: LocalizedError` with the underlying
  system error kept. README.

### Fixed (live recogniser)
- An unsupported locale left the stream open forever — it now fails with
  `recognizerUnavailable`; `isAvailable` is checked too.
- A `(nil, nil)` recognition callback crashed the host app with `fatalError` — the stream ends.
- The microphone permission was never requested (iOS prompted mid-transcription; a refusal
  recorded silence) — `requestAuthorization()` asks for it, `transcribe` refuses to start
  without it.
- Installing the tap with a 0 Hz input format (no microphone, some simulators) was a fatal
  `AVAudioEngine` assertion — reported as `invalidInputFormat` instead.
- Recognition errors lost their cause (`taskError`) — kept in `recognitionFailed(underlying:)`.
- `finishTask()` left the `.record` / `.duckOthers` session active, ducking the rest of the
  app's audio indefinitely, kept the engine/task references, and a second start leaked the
  previous stream — the session is deactivated, everything is released, a new transcription
  ends the previous one.
- The stream now ends on the final result instead of staying open.

### Changed
- Locale and audio-session policy are configuration, not hardcoded (`preferredLanguages[0]`
  and `.record/.measurement/.duckOthers` remain the defaults).
- Models split into one file per type under `Models/`, all with memberwise `public init`.

### Deprecated
- `SpeechClient` (and its `Failure`), now a thin layer over `SpeechRecognizer`; see the README
  migration table. Removed in 1.0.

## [0.2.0] - 2026-09-12

### Removed
- The Composable Architecture dependency (`@DependencyClient`, `DependencyKey`,
  `DependencyValues.speechClient`). `SpeechClient` became a plain struct with a public
  initializer; `UncheckedSendable`/`LockIsolated` reimplemented internally.

### Fixed
- `previewValue`'s stream never called `finish()`, so consumers never left their `for await`.

### Added
- Swift Testing target.

## [0.1.8]

Last release before this changelog.
