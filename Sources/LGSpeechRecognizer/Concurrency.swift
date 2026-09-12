//
//  Concurrency.swift
//  LGSpeechRecognizer
//
//  Two small helpers that used to come from swift-concurrency-extras through the
//  Composable Architecture dependency. Kept under the same names so the call sites read
//  the same; internal to the package.
//

import Foundation

/// Carries a non-`Sendable` value across an isolation boundary when the caller guarantees
/// it is not accessed concurrently (the Speech framework's request and task objects are
/// only ever touched from the recognition callbacks that own them).
struct UncheckedSendable<Value>: @unchecked Sendable {
    var wrappedValue: Value

    init(_ wrappedValue: Value) {
        self.wrappedValue = wrappedValue
    }
}

/// A value guarded by a lock, readable and writable from any isolation.
final class LockIsolated<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: Value

    init(_ value: Value) {
        storage = value
    }

    var value: Value {
        lock.withLock { storage }
    }

    func setValue(_ newValue: Value) {
        lock.withLock { storage = newValue }
    }
}
