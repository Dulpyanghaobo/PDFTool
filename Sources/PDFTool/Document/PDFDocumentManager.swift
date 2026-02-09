#if canImport(PDFKit)
import PDFKit
#endif
import Foundation
import CoreGraphics

#if canImport(UIKit)
import UIKit
#endif

/// Manages PDF document operations
public final class PDFDocumentManager: @unchecked Sendable {
    
    // MARK: - Singleton
    
    public static let shared = PDFDocumentManager()
    
    private init() {}
    
    // MARK: - Document Operations
    
    /// Open a PDF document from a URL
    /// - Parameter url: The URL of the PDF file
    /// - Returns: PDFDocument if successful
    public func openDocument(at url: URL) throws -> PDFDocument {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw PDFToolError.fileNotFound(url)
        }
        guard let document = PDFDocument(url: url) else {
            throw PDFToolError.invalidPDF(url)
        }
        return document
    }
    
    /// Get the page count of a PDF at a URL
    /// - Parameter url: The URL of the PDF file
    /// - Returns: Number of pages
    public func pageCount(at url: URL) throws -> Int {
        let document = try openDocument(at: url)
        return document.pageCount
    }
    
    /// Check if a PDF is encrypted and locked
    /// - Parameter url: The URL of the PDF file
    /// - Returns: Tuple indicating (isEncrypted, isLocked)
    public func encryptionStatus(at url: URL) throws -> (isEncrypted: Bool, isLocked: Bool) {
        let document = try openDocument(at: url)
        return (document.isEncrypted, document.isLocked)
    }
    
    /// Copy a PDF file to a new location
    /// - Parameters:
    ///   - source: Source URL
    ///   - destination: Destination URL
    public func copyDocument(from source: URL, to destination: URL) throws {
        let fm = FileManager.default
        
        // Ensure destination directory exists
        let destDir = destination.deletingLastPathComponent()
        try fm.createDirectory(at: destDir, withIntermediateDirectories: true)
        
        // Remove existing file if present
        if fm.fileExists(atPath: destination.path) {
            try fm.removeItem(at: destination)
        }
        
        try fm.copyItem(at: source, to: destination)
    }
    
    /// Create a new empty PDF document
    /// - Returns: A new empty PDFDocument
    public func createEmptyDocument() -> PDFDocument {
        return PDFDocument()
    }
    
    /// Save a PDF document to a URL
    /// - Parameters:
    ///   - document: The PDF document to save
    ///   - url: The destination URL
    public func saveDocument(_ document: PDFDocument, to url: URL) throws {
        let fm = FileManager.default
        let destDir = url.deletingLastPathComponent()
        try fm.createDirectory(at: destDir, withIntermediateDirectories: true)
        
        guard document.write(to: url) else {
            throw PDFToolError.cannotWritePDF(url)
        }
    }
    
    /// Atomically write a PDF document to a URL
    /// - Parameters:
    ///   - document: The PDF document to save
    ///   - url: The destination URL
    public func atomicWrite(_ document: PDFDocument, to url: URL) throws {
        let fm = FileManager.default
        let tmpURL = url.deletingLastPathComponent()
            .appendingPathComponent(UUID().uuidString + ".pdf")
        
        guard document.write(to: tmpURL) else {
            throw PDFToolError.cannotWritePDF(url)
        }
        
        if fm.fileExists(atPath: url.path) {
            try fm.removeItem(at: url)
        }
        try fm.moveItem(at: tmpURL, to: url)
    }
    
    /// Merge multiple PDF documents into one
    /// - Parameter urls: Array of PDF URLs to merge
    /// - Returns: A new merged PDFDocument
    public func mergeDocuments(from urls: [URL]) throws -> PDFDocument {
        let merged = PDFDocument()
        var insertIndex = 0
        
        for url in urls {
            let doc = try openDocument(at: url)
            
            // Skip encrypted and locked documents
            if doc.isEncrypted && doc.isLocked {
                continue
            }
            
            for i in 0..<doc.pageCount {
                if let page = doc.page(at: i) {
                    merged.insert(page, at: insertIndex)
                    insertIndex += 1
                }
            }
        }
        
        return merged
    }
    
    /// Extract specific pages from a PDF document
    /// - Parameters:
    ///   - url: Source PDF URL
    ///   - pageIndices: Indices of pages to extract (0-based)
    /// - Returns: A new PDFDocument with extracted pages
    public func extractPages(from url: URL, pageIndices: [Int]) throws -> PDFDocument {
        let source = try openDocument(at: url)
        let extracted = PDFDocument()
        
        for (insertIdx, pageIdx) in pageIndices.enumerated() {
            guard pageIdx >= 0 && pageIdx < source.pageCount else {
                throw PDFToolError.pageIndexOutOfRange(index: pageIdx, count: source.pageCount)
            }
            if let page = source.page(at: pageIdx) {
                extracted.insert(page, at: insertIdx)
            }
        }
        
        return extracted
    }
    
    /// Split a PDF document by page ranges
    /// - Parameters:
    ///   - url: Source PDF URL
    ///   - ranges: Array of page ranges (each range is an array of page indices)
    /// - Returns: Array of new PDFDocuments, one per range
    public func splitDocument(at url: URL, by ranges: [[Int]]) throws -> [PDFDocument] {
        let source = try openDocument(at: url)
        var results: [PDFDocument] = []
        
        for range in ranges {
            let doc = PDFDocument()
            for (insertIdx, pageIdx) in range.enumerated() {
                guard pageIdx >= 0 && pageIdx < source.pageCount else {
                    throw PDFToolError.pageIndexOutOfRange(index: pageIdx, count: source.pageCount)
                }
                if let page = source.page(at: pageIdx) {
                    doc.insert(page, at: insertIdx)
                }
            }
            results.append(doc)
        }
        
        return results
    }
}

// MARK: - Data Representation

public extension PDFDocumentManager {
    
    /// Get the data representation of a PDF document
    /// - Parameter document: The PDF document
    /// - Returns: Data representation
    func dataRepresentation(of document: PDFDocument) throws -> Data {
        guard let data = document.dataRepresentation() else {
            throw PDFToolError.exportFailed(reason: "Cannot get data representation")
        }
        return data
    }
    
    /// Create a PDF document from data
    /// - Parameter data: PDF data
    /// - Returns: PDFDocument
    func document(from data: Data) throws -> PDFDocument {
        guard let document = PDFDocument(data: data) else {
            throw PDFToolError.cannotCreatePDF
        }
        return document
    }
}