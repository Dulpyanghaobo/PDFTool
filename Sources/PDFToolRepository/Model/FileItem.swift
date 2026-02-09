//
//  FileItem.swift
//  PDFToolRepository
//
//  Lightweight value type for file/folder representation
//

import Foundation
import CoreGraphics
#if canImport(UIKit)
import UIKit
import PencilKit
#endif
import UniformTypeIdentifiers

// MARK: - FileItem
public struct FileItem: Identifiable, Sendable {

    public let id: UUID
    public var kind: FileItemKind
    public var name: String
    public var tags: Set<String>
    public var createdAt: Date
    public var updatedAt: Date
    public var parentID: UUID?
    public var currentRevisionID: UUID?
    public var pages: [PageItem]?
    public var pageCount: Int
    public var thumbnail: Data?
    public var contentKind: ContentKind
    public var fileUTI: String?
    public var fileSize: Int64?
    public var relativePath: String?

    public init(
        id: UUID = UUID(),
        kind: FileItemKind,
        name: String,
        tags: Set<String> = [],
        createdAt: Date = .now,
        updatedAt: Date = .now,
        parentID: UUID? = nil,
        currentRevisionID: UUID? = nil,
        pages: [PageItem]? = nil,
        pageCount: Int = 0,
        thumbnail: Data? = nil,
        contentKind: ContentKind = .pdf,
        fileUTI: String? = nil,
        fileSize: Int64? = nil,
        relativePath: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.name = name
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.parentID = parentID
        self.currentRevisionID = currentRevisionID
        self.pages = pages
        self.pageCount = pageCount
        self.thumbnail = thumbnail
        self.contentKind = contentKind
        self.fileUTI = fileUTI
        self.fileSize = fileSize
        self.relativePath = relativePath
    }

    public var isPDF: Bool {
        if contentKind == .pdf { return true }
        if let uti = fileUTI { return uti == UTType.pdf.identifier }
        return false
    }

    public var isImages: Bool { contentKind == .images }
}

extension FileItem: Equatable {
    public static func == (lhs: FileItem, rhs: FileItem) -> Bool {
        lhs.id == rhs.id
    }
}

extension FileItem: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - PageItem
public struct PageItem: Identifiable, Sendable {
    public let id: UUID
    public var index: Int
    public var bbox: CGRect?
    public var paperSize: String?
    public var rotation: Int?
    public var filters: [String]
    public var thumbnail: Data?
    public var noteTexts: [String]?
    public let revision: RevisionItem?

    public init(
        id: UUID = UUID(),
        index: Int,
        bbox: CGRect? = nil,
        paperSize: String? = nil,
        rotation: Int? = nil,
        filters: [String] = [],
        thumbnail: Data? = nil,
        noteTexts: [String]? = nil,
        revision: RevisionItem? = nil
    ) {
        self.id = id
        self.index = index
        self.bbox = bbox
        self.paperSize = paperSize
        self.rotation = rotation
        self.filters = filters
        self.thumbnail = thumbnail
        self.noteTexts = noteTexts
        self.revision = revision
    }

    #if canImport(UIKit)
    /// Convert thumbnail to UIImage
    public func toUIImage() -> UIImage? {
        if let data = revision?.thumbnail {
            return UIImage(data: data)
        } else if let data = thumbnail {
            return UIImage(data: data)
        }
        return nil
    }

    public func toOriginalImage() -> UIImage? {
        if let data = thumbnail {
            return UIImage(data: data)
        }
        return nil
    }

    public func toCGImage() -> CGImage? {
        toUIImage()?.cgImage
    }
    #endif

    /// Return a copy with a new revision
    public func withNewRevision(_ revision: RevisionItem, thumb: Data? = nil) -> PageItem {
        PageItem(
            id: id,
            index: index,
            bbox: bbox,
            paperSize: paperSize,
            rotation: rotation,
            filters: filters,
            thumbnail: thumbnail,
            noteTexts: noteTexts,
            revision: revision
        )
    }
}

extension PageItem: Equatable {
    public static func == (lhs: PageItem, rhs: PageItem) -> Bool {
        lhs.id == rhs.id && lhs.index == rhs.index
    }
}

extension PageItem: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(index)
    }
}

// MARK: - RevisionItem
public struct RevisionItem: Identifiable, Sendable {
    public let id: UUID
    public let createdAt: Date
    public let editOps: [EditOp]
    public let assetURL: URL?
    public let thumbnail: Data?

    public init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        editOps: [EditOp] = [],
        assetURL: URL? = nil,
        thumbnail: Data? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.editOps = editOps
        self.assetURL = assetURL
        self.thumbnail = thumbnail
    }
}

extension RevisionItem: Equatable {
    public static func == (lhs: RevisionItem, rhs: RevisionItem) -> Bool {
        lhs.id == rhs.id
    }
}

extension RevisionItem: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - NoteItem
public struct NoteItem: Identifiable, Sendable {
    public let id: UUID
    public var textMD: String
    public var unitRect: CGRect
    public var pageKey: NotePageKey
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        textMD: String,
        unitRect: CGRect = .zero,
        pageKey: NotePageKey,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.textMD = textMD
        self.unitRect = unitRect
        self.pageKey = pageKey
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension NoteItem: Equatable {
    public static func == (lhs: NoteItem, rhs: NoteItem) -> Bool {
        lhs.id == rhs.id
    }
}

extension NoteItem: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - SignatureItem
public struct SignatureItem: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var name: String?
    public var drawingData: Data
    public var inkColor: InkColor
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        name: String? = nil,
        drawingData: Data,
        inkColor: InkColor = .black,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.drawingData = drawingData
        self.inkColor = inkColor
        self.createdAt = createdAt
    }

    #if canImport(UIKit)
    public var rasterImage: UIImage? {
        guard let drawing = try? PKDrawing(data: drawingData),
              !drawing.bounds.isEmpty else { return nil }
        let bounds = drawing.bounds.insetBy(dx: -1, dy: -1)
        let scale: CGFloat = 3
        return drawing.image(from: bounds, scale: scale).withRenderingMode(.alwaysTemplate)
    }
    #endif
}

// MARK: - InkColor
public struct InkColor: Hashable, Sendable {
    public let hexString: String

    public init(hexString: String) {
        self.hexString = hexString
    }

    public static let black = InkColor(hexString: "#000000")
    public static let blue = InkColor(hexString: "#0000FF")
    public static let red = InkColor(hexString: "#FF0000")
}

// MARK: - InkPlacementDTO
public struct InkPlacementDTO: Sendable {
    public let signatureID: UUID
    public let pageIndex: Int
    public let position: CGPoint
    public let scale: CGFloat
    public let colorHex: String

    public init(
        signatureID: UUID,
        pageIndex: Int,
        position: CGPoint,
        scale: CGFloat,
        colorHex: String
    ) {
        self.signatureID = signatureID
        self.pageIndex = pageIndex
        self.position = position
        self.scale = scale
        self.colorHex = colorHex
    }
}