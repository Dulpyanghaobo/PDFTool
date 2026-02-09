#if canImport(PDFKit)
import PDFKit
#endif
import Foundation
import CoreGraphics

#if canImport(UIKit)
import UIKit
#endif

/// Handles PDF page-level operations
public final class PDFPageOperations: @unchecked Sendable {
    
    // MARK: - Singleton
    
    public static let shared = PDFPageOperations()
    
    private init() {}
    
    // MARK: - Page Insertion
    
    /// Insert images as new pages into a PDF document
    /// - Parameters:
    ///   - imageURLs: URLs of images to insert
    ///   - document: Target PDF document
    ///   - index: Insertion index (nil = append at end)
    /// - Returns: Number of pages after insertion
    @discardableResult
    public func insertImages(_ imageURLs: [URL], into document: PDFDocument, at index: Int? = nil) throws -> Int {
        let insertBase = index ?? document.pageCount
        let clampedIndex = max(0, min(insertBase, document.pageCount))
        
        var offset = 0
        for imageURL in imageURLs {
            let page = try makePDFPage(from: imageURL)
            document.insert(page, at: clampedIndex + offset)
            offset += 1
        }
        
        return document.pageCount
    }
    
    /// Insert pages from another PDF into a document
    /// - Parameters:
    ///   - sourceURL: URL of source PDF
    ///   - document: Target PDF document
    ///   - index: Insertion index (nil = append at end)
    /// - Returns: Number of pages after insertion
    @discardableResult
    public func insertPDF(from sourceURL: URL, into document: PDFDocument, at index: Int? = nil) throws -> Int {
        guard let source = PDFDocument(url: sourceURL) else {
            throw PDFToolError.invalidPDF(sourceURL)
        }
        
        let insertBase = index ?? document.pageCount
        let clampedIndex = max(0, min(insertBase, document.pageCount))
        
        var offset = 0
        for i in 0..<source.pageCount {
            if let page = source.page(at: i) {
                document.insert(page, at: clampedIndex + offset)
                offset += 1
            }
        }
        
        return document.pageCount
    }
    
    #if canImport(UIKit)
    /// Insert UIImages as new pages into a PDF document
    /// - Parameters:
    ///   - images: UIImages to insert
    ///   - document: Target PDF document
    ///   - index: Insertion index (nil = append at end)
    /// - Returns: Number of pages after insertion
    @discardableResult
    public func insertUIImages(_ images: [UIImage], into document: PDFDocument, at index: Int? = nil) throws -> Int {
        let insertBase = index ?? document.pageCount
        let clampedIndex = max(0, min(insertBase, document.pageCount))
        
        var offset = 0
        for image in images {
            guard let page = PDFPage(image: image) else {
                throw PDFToolError.invalidImage
            }
            document.insert(page, at: clampedIndex + offset)
            offset += 1
        }
        
        return document.pageCount
    }
    #endif
    
    // MARK: - Page Deletion
    
    /// Delete pages from a PDF document
    /// - Parameters:
    ///   - indices: Set of page indices to delete (0-based)
    ///   - document: Target PDF document
    public func deletePages(at indices: IndexSet, from document: PDFDocument) {
        // Delete in reverse order to maintain correct indices
        let sorted = Array(indices).sorted(by: >)
        for idx in sorted where idx < document.pageCount {
            document.removePage(at: idx)
        }
    }
    
    // MARK: - Page Replacement
    
    /// Replace pages in a PDF document with images
    /// - Parameters:
    ///   - indices: Indices of pages to replace
    ///   - imageURLs: URLs of replacement images (must match count)
    ///   - document: Target PDF document
    public func replacePages(at indices: IndexSet, with imageURLs: [URL], in document: PDFDocument) throws {
        guard indices.count == imageURLs.count else {
            throw PDFToolError.exportFailed(reason: "Index count must match image count")
        }
        
        let sorted = Array(indices).sorted()
        for (i, idx) in sorted.enumerated() {
            if idx < document.pageCount {
                document.removePage(at: idx)
            }
            let page = try makePDFPage(from: imageURLs[i])
            document.insert(page, at: min(idx, document.pageCount))
        }
    }
    
    #if canImport(UIKit)
    /// Replace pages in a PDF document with UIImages
    /// - Parameters:
    ///   - indices: Indices of pages to replace
    ///   - images: Replacement UIImages (must match count)
    ///   - document: Target PDF document
    public func replacePages(at indices: IndexSet, with images: [UIImage], in document: PDFDocument) throws {
        guard indices.count == images.count else {
            throw PDFToolError.exportFailed(reason: "Index count must match image count")
        }
        
        let sorted = Array(indices).sorted()
        for (i, idx) in sorted.enumerated() {
            if idx < document.pageCount {
                document.removePage(at: idx)
            }
            guard let page = PDFPage(image: images[i]) else {
                throw PDFToolError.invalidImage
            }
            document.insert(page, at: min(idx, document.pageCount))
        }
    }
    #endif
    
    // MARK: - Page Swapping
    
    /// Swap two pages in a PDF document
    /// - Parameters:
    ///   - indexA: First page index
    ///   - indexB: Second page index
    ///   - document: Target PDF document
    public func swapPages(_ indexA: Int, _ indexB: Int, in document: PDFDocument) throws {
        guard indexA != indexB else { return }
        
        let pageCount = document.pageCount
        guard indexA >= 0 && indexA < pageCount else {
            throw PDFToolError.pageIndexOutOfRange(index: indexA, count: pageCount)
        }
        guard indexB >= 0 && indexB < pageCount else {
            throw PDFToolError.pageIndexOutOfRange(index: indexB, count: pageCount)
        }
        
        // Extract all pages
        let pages = (0..<pageCount).compactMap { document.page(at: $0) }
        
        // Create new order
        var order = Array(0..<pages.count)
        order.swapAt(indexA, indexB)
        
        // Rebuild document
        let newDoc = PDFDocument()
        for idx in order {
            newDoc.insert(pages[idx], at: newDoc.pageCount)
        }
        
        // Copy back to original document
        while document.pageCount > 0 {
            document.removePage(at: 0)
        }
        for i in 0..<newDoc.pageCount {
            if let page = newDoc.page(at: i) {
                document.insert(page, at: document.pageCount)
            }
        }
    }
    
    // MARK: - Page Reordering
    
    /// Reorder pages in a PDF document
    /// - Parameters:
    ///   - newOrder: Array of page indices representing new order
    ///   - document: Target PDF document
    public func reorderPages(to newOrder: [Int], in document: PDFDocument) throws {
        let pageCount = document.pageCount
        
        // Validate indices
        for idx in newOrder {
            guard idx >= 0 && idx < pageCount else {
                throw PDFToolError.pageIndexOutOfRange(index: idx, count: pageCount)
            }
        }
        
        // Extract pages in new order
        let newDoc = PDFDocument()
        for idx in newOrder {
            if let page = document.page(at: idx) {
                newDoc.insert(page, at: newDoc.pageCount)
            }
        }
        
        // Copy back to original document
        while document.pageCount > 0 {
            document.removePage(at: 0)
        }
        for i in 0..<newDoc.pageCount {
            if let page = newDoc.page(at: i) {
                document.insert(page, at: document.pageCount)
            }
        }
    }
    
    // MARK: - Page Rotation
    
    /// Rotate pages in a PDF document
    /// - Parameters:
    ///   - indices: Indices of pages to rotate
    ///   - quarterTurns: Number of 90-degree clockwise rotations
    ///   - document: Target PDF document
    public func rotatePages(at indices: IndexSet, by quarterTurns: Int, in document: PDFDocument) {
        guard quarterTurns % 4 != 0 else { return }
        
        let delta = ((quarterTurns % 4) + 4) % 4
        for idx in indices {
            guard let page = document.page(at: idx) else { continue }
            let currentRotation = page.rotation
            page.rotation = (currentRotation + delta * 90) % 360
        }
    }
    
    /// Rotate pages using PDFPageRotation enum
    /// - Parameters:
    ///   - indices: Indices of pages to rotate
    ///   - rotation: Target rotation
    ///   - document: Target PDF document
    public func rotatePages(at indices: IndexSet, to rotation: PDFPageRotation, in document: PDFDocument) {
        rotatePages(at: indices, by: rotation.quarterTurns, in: document)
    }
    
    // MARK: - Helper Methods
    
    /// Create a PDFPage from an image URL
    /// - Parameter imageURL: URL of the image
    /// - Returns: PDFPage
    public func makePDFPage(from imageURL: URL) throws -> PDFPage {
        #if canImport(UIKit)
        guard let image = UIImage(contentsOfFile: imageURL.path) else {
            throw PDFToolError.ioError("Cannot load image at: \(imageURL.path)")
        }
        guard let page = PDFPage(image: image) else {
            throw PDFToolError.invalidImage
        }
        return page
        #else
        throw PDFToolError.exportFailed(reason: "UIKit not available")
        #endif
    }
    
    #if canImport(UIKit)
    /// Create a PDFPage from a UIImage
    /// - Parameter image: The UIImage
    /// - Returns: PDFPage
    public func makePDFPage(from image: UIImage) throws -> PDFPage {
        guard let page = PDFPage(image: image) else {
            throw PDFToolError.invalidImage
        }
        return page
    }
    #endif
}

// MARK: - File-based Operations

public extension PDFPageOperations {
    
    /// Insert images into a PDF file and save
    /// - Parameters:
    ///   - imageURLs: URLs of images to insert
    ///   - pdfURL: URL of the PDF file
    ///   - index: Insertion index (nil = append at end)
    /// - Returns: Number of pages after insertion
    @discardableResult
    func insertImagesAndSave(_ imageURLs: [URL], into pdfURL: URL, at index: Int? = nil) throws -> Int {
        let document = try PDFDocumentManager.shared.openDocument(at: pdfURL)
        let count = try insertImages(imageURLs, into: document, at: index)
        try PDFDocumentManager.shared.atomicWrite(document, to: pdfURL)
        return count
    }
    
    /// Delete pages from a PDF file and save
    /// - Parameters:
    ///   - indices: Set of page indices to delete
    ///   - pdfURL: URL of the PDF file
    func deletePagesAndSave(at indices: IndexSet, from pdfURL: URL) throws {
        let document = try PDFDocumentManager.shared.openDocument(at: pdfURL)
        deletePages(at: indices, from: document)
        try PDFDocumentManager.shared.atomicWrite(document, to: pdfURL)
    }
    
    /// Swap pages in a PDF file and save
    /// - Parameters:
    ///   - indexA: First page index
    ///   - indexB: Second page index
    ///   - pdfURL: URL of the PDF file
    func swapPagesAndSave(_ indexA: Int, _ indexB: Int, in pdfURL: URL) throws {
        let document = try PDFDocumentManager.shared.openDocument(at: pdfURL)
        try swapPages(indexA, indexB, in: document)
        try PDFDocumentManager.shared.atomicWrite(document, to: pdfURL)
    }
    
    /// Reorder pages in a PDF file and save
    /// - Parameters:
    ///   - newOrder: Array of page indices representing new order
    ///   - pdfURL: URL of the PDF file
    func reorderPagesAndSave(to newOrder: [Int], in pdfURL: URL) throws {
        let document = try PDFDocumentManager.shared.openDocument(at: pdfURL)
        try reorderPages(to: newOrder, in: document)
        try PDFDocumentManager.shared.atomicWrite(document, to: pdfURL)
    }
    
    /// Rotate pages in a PDF file and save
    /// - Parameters:
    ///   - indices: Indices of pages to rotate
    ///   - quarterTurns: Number of 90-degree clockwise rotations
    ///   - pdfURL: URL of the PDF file
    func rotatePagesAndSave(at indices: IndexSet, by quarterTurns: Int, in pdfURL: URL) throws {
        let document = try PDFDocumentManager.shared.openDocument(at: pdfURL)
        rotatePages(at: indices, by: quarterTurns, in: document)
        try PDFDocumentManager.shared.atomicWrite(document, to: pdfURL)
    }
}