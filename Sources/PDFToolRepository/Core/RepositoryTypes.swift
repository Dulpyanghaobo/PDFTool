//
//  RepositoryTypes.swift
//  PDFToolRepository
//
//  Core types for file system repository
//

import Foundation
import CoreGraphics

// MARK: - Document Content Kind
public enum DocContentKind: Int, Codable, Sendable {
    case pdf = 0
    case images = 1
}

// MARK: - PDF Variant
public enum PDFVariant: String, Sendable {
    case working
    case original
    case cropped
}

// MARK: - File Item Kind
public enum FileItemKind: String, Sendable {
    case folder
    case document
}

// MARK: - Content Kind
public enum ContentKind: String, Sendable {
    case images
    case pdf
    case blob
}

// MARK: - File System Error
public enum FileSystemError: Error, Sendable {
    case notFound(UUID)
    case duplicatedName(String, containerID: UUID?)
    case permissionDenied
    case ioFailure(underlying: Error)
    case invalidOperation(reason: String)
}

extension FileSystemError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notFound(let id):
            return "Item with ID \(id) was not found."
        case .duplicatedName(let name, _):
            return "An item named '\(name)' already exists in the destination."
        case .permissionDenied:
            return "You don't have permission to perform this operation."
        case .ioFailure(let underlying):
            return "An I/O error occurred: \(underlying.localizedDescription)"
        case .invalidOperation(let reason):
            return reason
        }
    }
}

// MARK: - File Event
public enum FileEvent: Sendable {
    case added(FileItem)
    case removed(id: UUID, parentID: UUID?)
    case updated(FileItem)
    case moved(id: UUID, fromParent: UUID?, toParent: UUID?)
}

// MARK: - Note Page Key
public enum NotePageKey: Hashable, Sendable {
    case image(pageID: UUID, index: Int)
    case pdf(index: Int)
    
    // Legacy compatibility
    public static func image(_ index: Int) -> NotePageKey {
        return .image(pageID: UUID(), index: index)
    }
}

// MARK: - Thumbnail Output Format
public enum ThumbnailOutputFormat: Sendable {
    case jpeg
    case png
}

// MARK: - Page Image Source
public enum PageImageSource: Sendable {
    case processed
    case original
}
