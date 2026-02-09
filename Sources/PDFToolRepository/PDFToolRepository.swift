//
//  PDFToolRepository.swift
//  PDFToolRepository
//
//  Main entry point and public exports
//

import Foundation
import CoreGraphics
#if canImport(UIKit)
import UIKit
import PencilKit
#endif

// MARK: - FileSystemMonitor Implementation
public actor SDMonitor: FileSystemMonitor {
    private var continuations: [UUID: AsyncStream<FileEvent>.Continuation] = [:]

    public init() {}

    public nonisolated var events: AsyncStream<FileEvent> {
        AsyncStream<FileEvent>(bufferingPolicy: .unbounded) { continuation in
            let id = UUID()
            let weakSelf = self
            Task { await weakSelf.add(continuation, id: id) }
            continuation.onTermination = { @Sendable _ in
                Task { await weakSelf.remove(id) }
            }
        }
    }

    public nonisolated func send(_ ev: FileEvent) {
        Task { await _send(ev) }
    }

    private func add(_ cont: AsyncStream<FileEvent>.Continuation, id: UUID) {
        continuations[id] = cont
    }

    private func remove(_ id: UUID) {
        continuations.removeValue(forKey: id)
    }

    private func _send(_ ev: FileEvent) {
        for c in continuations.values {
            c.yield(ev)
        }
    }

    deinit {
        continuations.values.forEach { $0.finish() }
        continuations.removeAll()
    }
}

// MARK: - PDFToolRepository Namespace
public enum PDFToolRepositoryInfo {
    public static let version = "1.0.0"
}