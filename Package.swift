// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LGSpeechRecognizer",
    platforms: [.iOS(.v17)],
    products: [
        .library(
            name: "LGSpeechRecognizer",
            targets: ["LGSpeechRecognizer"]),
    ],
    // No dependencies: plain Swift Concurrency over the Speech framework.
    targets: [
        .target(
            name: "LGSpeechRecognizer"
        ),
        .testTarget(
            name: "LGSpeechRecognizerTests",
            dependencies: ["LGSpeechRecognizer"]
        ),
    ]
)
