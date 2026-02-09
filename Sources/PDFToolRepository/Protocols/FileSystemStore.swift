//
//  FileSystemStore.swift
//  PDFToolRepository
//
//  Main protocol for file system operations
//

import Foundation

// MARK: - FSNavigationAPI
public protocol FSNavigationAPI: AnyObject, Sendable {
    var rootFolderID: UUID { get }
    func rootFolder() async throws -> FileItem
    func items(in parent: FileItem?) async throws -> [FileItem]
    func item(for id: UUID) async throws -> FileItem
    func createFolder(named name: String, in parent: FileItem?) async throws -> FileItem
    func rename(_ item: FileItem, to newName: String) async throws
    func delete(_ item: FileItem) async throws
    func move(_ items: [FileItem], to destination: FileItem?) async throws
    func update(_ item: FileItem) async throws
}

// MARK: - FSPDFAPI
public protocol FSPDFAPI: AnyObject, Sendable {
    func documentURL(for documentID: UUID) async throws -> URL
    func pdfURL(for documentID: UUID, variant: PDFVariant) async throws -> URL
    func pageCount(for documentID: UUID) async throws -> Int
    func croppedURLIfExists(for documentID: UUID) async -> URL?
}

// MARK: - FSPDFPagesAPI
public protocol FSPDFPagesAPI: AnyObject, Sendable {
    func insertImages(_ images: [URL], into documentID: UUID, at index: Int?) async throws -> Int
    func insertPDF(_ pdfURL: URL, into documentID: UUID, at index: Int?) async throws -> Int
    func replacePages(in documentID: UUID, at indexes: IndexSet, with images: [URL]) async throws
    func replacePagesInCropped(in documentID: UUID, at indexes: IndexSet, with images: [URL]) async throws
    func deletePages(in documentID: UUID, at indexes: IndexSet) async throws
    func swapPages(in documentID: UUID, _ a: Int, _ b: Int) async throws
    func reorderPages(in documentID: UUID, newOrder: [Int]) async throws
    func rotatePages(in documentID: UUID, at indexes: IndexSet, quarterTurns: Int) async throws
    func applyPageSizes(in documentID: UUID, changes: [Int: PageSize]) async throws
}

// MARK: - FSFiltersAPI
public protocol FSFiltersAPI: AnyObject, Sendable {
    func pageFilters(for documentID: UUID) throws -> [[String]]
    func setPageFilters(for documentID: UUID, page: Int, filters: [String]) throws
}

// MARK: - FSImagesAPI
public protocol FSImagesAPI: AnyObject, Sendable {
    func createImagesDocument(named title: String, from images: [URL], in parent: FileItem?) async throws -> FileItem
}

// MARK: - FSRevisionsAPI
public protocol FSRevisionsAPI: AnyObject, Sendable {
    func commitRevisionPreview(in documentID: UUID, pageIndex: Int, preview: Data, editOps: [EditOp], note: String?) async throws
}

// MARK: - FSSignaturesAPI
public protocol FSSignaturesAPI: AnyObject, Sendable {
    func signatures(sortedByNewest: Bool) throws -> [SignatureItem]
    func signature(id: UUID) throws -> SignatureItem
    @discardableResult
    func createSignature(name: String?, drawingData: Data, inkColorHex: String) throws -> SignatureItem
    func update(_ signature: SignatureItem) throws
    func deleteSignature(id: UUID) throws
}

// MARK: - FSRecentsAPI
public protocol FSRecentsAPI: AnyObject, Sendable {
    func recentDocuments(days: Int) async throws -> [FileItem]
}

// MARK: - FSNoteAPI
public protocol FSNoteAPI: AnyObject, Sendable {
    func notes(in documentID: UUID, on page: NotePageKey) throws -> [NoteItem]
    @discardableResult
    func addNote(_ textMD: String, to documentID: UUID, on page: NotePageKey, unitRect: CGRect?) throws -> NoteItem
    func moveNote(_ noteID: UUID, to page: NotePageKey) throws
    func updateNoteText(_ noteID: UUID, textMD: String) throws
    func deleteNote(_ noteID: UUID) throws
}

// MARK: - FileSystemStore (Combined Protocol)
public protocol FileSystemStore:
    FSNavigationAPI,
    FSPDFAPI,
    FSPDFPagesAPI,
    FSFiltersAPI,
    FSImagesAPI,
    FSRevisionsAPI,
    FSSignaturesAPI,
    FSRecentsAPI,
    FSNoteAPI
{}

// MARK: - Default Implementations
public extension FileSystemStore {
    func rootFolder() async throws -> FileItem {
        throw FileSystemError.invalidOperation(reason: "rootFolder not implemented for \(Self.self)")
    }
    func items(in parent: FileItem?) async throws -> [FileItem] {
        throw FileSystemError.invalidOperation(reason: "items(in:) not implemented")
    }
    func item(for id: UUID) async throws -> FileItem {
        throw FileSystemError.invalidOperation(reason: "item(for:) not implemented")
    }
    func createFolder(named name: String, in parent: FileItem?) async throws -> FileItem {
        throw FileSystemError.invalidOperation(reason: "createFolder not implemented")
    }
    func rename(_ item: FileItem, to newName: String) async throws {
        throw FileSystemError.invalidOperation(reason: "rename not implemented")
    }
    func delete(_ item: FileItem) async throws {
        throw FileSystemError.invalidOperation(reason: "delete not implemented")
    }
    func move(_ items: [FileItem], to destination: FileItem?) async throws {
        throw FileSystemError.invalidOperation(reason: "move not implemented")
    }
    func update(_ item: FileItem) async throws {
        throw FileSystemError.invalidOperation(reason: "update(item:) not implemented")
    }
    func pdfURL(for documentID: UUID, variant: PDFVariant) async throws -> URL {
        throw FileSystemError.invalidOperation(reason: "pdfURL(variant:) not implemented")
    }
    func documentURL(for documentID: UUID) async throws -> URL {
        throw FileSystemError.invalidOperation(reason: "documentURL not implemented")
    }
    func pageCount(for documentID: UUID) async throws -> Int {
        throw FileSystemError.invalidOperation(reason: "pageCount not implemented")
    }
    func recentDocuments(days: Int) async throws -> [FileItem] {
        throw FileSystemError.invalidOperation(reason: "recentDocuments(days:) not implemented")
    }
}

// MARK: - FileSystemMonitor Protocol
public protocol FileSystemMonitor: AnyObject, Sendable {
    var events: AsyncStream<FileEvent> { get }
    func send(_ ev: FileEvent)
}