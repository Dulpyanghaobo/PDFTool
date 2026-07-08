import Foundation
#if canImport(PDFKit)
import PDFKit
#endif
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// PDFTool namespace
public enum PDFTool {
    /// Current version of PDFTool
    public static let version = "1.0.0"
}

#if canImport(PDFKit)
public struct PDFToolAnnotationColor: Equatable, Sendable {
    public var red: CGFloat
    public var green: CGFloat
    public var blue: CGFloat
    public var alpha: CGFloat

    public init(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    public static let yellow = PDFToolAnnotationColor(red: 1, green: 0.84, blue: 0.12, alpha: 0.35)
    public static let blue = PDFToolAnnotationColor(red: 0.2, green: 0.5, blue: 1, alpha: 0.35)
    public static let green = PDFToolAnnotationColor(red: 0.2, green: 0.78, blue: 0.42, alpha: 0.35)
    public static let pink = PDFToolAnnotationColor(red: 1, green: 0.35, blue: 0.7, alpha: 0.35)

    #if canImport(UIKit)
    var platformColor: UIColor {
        UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }
    #elseif canImport(AppKit)
    var platformColor: NSColor {
        NSColor(red: red, green: green, blue: blue, alpha: alpha)
    }
    #endif
}

public extension PDFTool {
    // MARK: - Document

    static func openDocument(at url: URL) throws -> PDFDocument {
        try PDFDocumentManager.shared.openDocument(at: url)
    }

    static func pageCount(at url: URL) throws -> Int {
        try PDFDocumentManager.shared.pageCount(at: url)
    }

    static func pageBounds(at url: URL, pageIndex: Int) throws -> CGRect {
        let document = try PDFDocumentManager.shared.openDocument(at: url)
        guard let page = document.page(at: pageIndex) else {
            throw PDFToolError.pageIndexOutOfRange(index: pageIndex, count: document.pageCount)
        }
        return page.bounds(for: .mediaBox)
    }

    static func copyPDF(from sourceURL: URL, to destinationURL: URL) throws {
        try PDFDocumentManager.shared.copyDocument(from: sourceURL, to: destinationURL)
    }

    @discardableResult
    static func mergePDFs(_ sourceURLs: [URL], to destinationURL: URL) throws -> Int {
        guard sourceURLs.isEmpty == false else {
            throw PDFToolError.cannotCreatePDF
        }

        let merged = try PDFDocumentManager.shared.mergeDocuments(from: sourceURLs)
        guard merged.pageCount > 0 else {
            throw PDFToolError.cannotCreatePDF
        }

        try PDFDocumentManager.shared.saveDocument(merged, to: destinationURL)
        return merged.pageCount
    }

    @discardableResult
    static func extractPages(from sourceURL: URL, pageIndices: [Int], to destinationURL: URL) throws -> Int {
        let extracted = try PDFDocumentManager.shared.extractPages(from: sourceURL, pageIndices: pageIndices)
        try PDFDocumentManager.shared.saveDocument(extracted, to: destinationURL)
        return extracted.pageCount
    }

    @discardableResult
    static func splitPDF(
        at sourceURL: URL,
        pageRanges: [Range<Int>],
        outputDirectory: URL,
        baseName: String = "part"
    ) throws -> [URL] {
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        var outputURLs: [URL] = []
        for (index, range) in pageRanges.enumerated() {
            let destinationURL = outputDirectory
                .appendingPathComponent("\(baseName)-\(index + 1)")
                .appendingPathExtension("pdf")
            _ = try extractPages(from: sourceURL, pageIndices: Array(range), to: destinationURL)
            outputURLs.append(destinationURL)
        }
        return outputURLs
    }

    // MARK: - Page Operations

    @discardableResult
    static func insertImages(_ imageURLs: [URL], into pdfURL: URL, at index: Int? = nil) throws -> Int {
        try PDFPageOperations.shared.insertImagesAndSave(imageURLs, into: pdfURL, at: index)
    }

    static func insertPDF(_ sourceURL: URL, into destinationURL: URL, at index: Int? = nil) throws -> Int {
        let document = try PDFDocumentManager.shared.openDocument(at: destinationURL)
        let count = try PDFPageOperations.shared.insertPDF(from: sourceURL, into: document, at: index)
        try PDFDocumentManager.shared.atomicWrite(document, to: destinationURL)
        return count
    }

    static func deletePages(at indices: IndexSet, from pdfURL: URL) throws {
        try PDFPageOperations.shared.deletePagesAndSave(at: indices, from: pdfURL)
    }

    static func rotatePages(at indices: IndexSet, by quarterTurns: Int, in pdfURL: URL) throws {
        try PDFPageOperations.shared.rotatePagesAndSave(at: indices, by: quarterTurns, in: pdfURL)
    }

    static func reorderPages(to newOrder: [Int], in pdfURL: URL) throws {
        try PDFPageOperations.shared.reorderPagesAndSave(to: newOrder, in: pdfURL)
    }

    static func swapPages(_ firstIndex: Int, _ secondIndex: Int, in pdfURL: URL) throws {
        try PDFPageOperations.shared.swapPagesAndSave(firstIndex, secondIndex, in: pdfURL)
    }

    // MARK: - Annotation

    static func addTextAnnotation(
        to pdfURL: URL,
        pageIndex: Int,
        bounds: CGRect,
        text: String,
        color: PDFToolAnnotationColor = PDFToolAnnotationColor(red: 1, green: 1, blue: 1, alpha: 0.95)
    ) throws {
        try addAnnotation(to: pdfURL, pageIndex: pageIndex) { page in
            let annotation = PDFAnnotation(bounds: bounds, forType: .freeText, withProperties: nil)
            annotation.contents = text
            annotation.color = color.platformColor
            annotation.shouldDisplay = true
            annotation.shouldPrint = true
            page.addAnnotation(annotation)
        }
    }

    static func addHighlightAnnotation(
        to pdfURL: URL,
        pageIndex: Int,
        bounds: CGRect,
        color: PDFToolAnnotationColor = .yellow
    ) throws {
        try addAnnotation(to: pdfURL, pageIndex: pageIndex) { page in
            let annotation = PDFAnnotation(bounds: bounds, forType: .highlight, withProperties: nil)
            annotation.color = color.platformColor
            annotation.shouldDisplay = true
            annotation.shouldPrint = true
            page.addAnnotation(annotation)
        }
    }

    static func addUnderlineAnnotation(
        to pdfURL: URL,
        pageIndex: Int,
        bounds: CGRect,
        color: PDFToolAnnotationColor = .blue
    ) throws {
        try addAnnotation(to: pdfURL, pageIndex: pageIndex) { page in
            let annotation = PDFAnnotation(bounds: bounds, forType: .underline, withProperties: nil)
            annotation.color = color.platformColor
            annotation.shouldDisplay = true
            annotation.shouldPrint = true
            page.addAnnotation(annotation)
        }
    }

    // MARK: - Export

    static func exportPDF(from sourceURL: URL, to destinationURL: URL, options: PDFExportOptions? = nil) throws {
        try PDFExporter.shared.exportDocument(from: sourceURL, to: destinationURL, options: options)
    }

    @discardableResult
    static func compressPDF(from sourceURL: URL, to destinationURL: URL, quality: CGFloat = 0.6) throws -> Int {
        try PDFExporter.shared.exportDocument(
            from: sourceURL,
            to: destinationURL,
            options: PDFExportOptions(compressionQuality: quality)
        )
        return try pageCount(at: destinationURL)
    }

    private static func addAnnotation(
        to pdfURL: URL,
        pageIndex: Int,
        mutate: (PDFPage) throws -> Void
    ) throws {
        let document = try PDFDocumentManager.shared.openDocument(at: pdfURL)
        guard let page = document.page(at: pageIndex) else {
            throw PDFToolError.pageIndexOutOfRange(index: pageIndex, count: document.pageCount)
        }

        try mutate(page)
        try PDFDocumentManager.shared.atomicWrite(document, to: pdfURL)
    }
}

#if canImport(UIKit)
public extension PDFTool {
    @discardableResult
    static func imageToPDF(_ images: [UIImage], to destinationURL: URL, options: PDFExportOptions? = nil) throws -> Int {
        guard images.isEmpty == false else {
            throw PDFToolError.invalidImage
        }

        try PDFExporter.shared.exportImages(images, to: destinationURL, options: options)
        return try pageCount(at: destinationURL)
    }

    @discardableResult
    static func pdfToJPEG(
        from sourceURL: URL,
        outputDirectory: URL,
        baseName: String = "page",
        quality: CGFloat = 0.9,
        pageIndices: [Int]? = nil
    ) throws -> [URL] {
        let count = try pageCount(at: sourceURL)
        let selected = pageIndices ?? Array(0..<count)
        let pages = selected.map { PDFExportablePageWrapper(url: sourceURL, pageIndex: $0) }
        return try PDFExporter.shared.exportToJPEGFiles(
            pages: pages,
            directory: outputDirectory,
            baseName: baseName,
            quality: quality
        )
    }

    static func renderPage(from sourceURL: URL, pageIndex: Int, maxLongSide: CGFloat = 2000) -> UIImage? {
        PDFRenderer.shared.renderPage(from: sourceURL, pageIndex: pageIndex, maxLongSide: maxLongSide)
    }

    static func renderAllPages(from sourceURL: URL, maxLongSide: CGFloat = 2000) -> [UIImage] {
        PDFRenderer.shared.renderAllPages(from: sourceURL, maxLongSide: maxLongSide)
    }

    static func thumbnail(from sourceURL: URL, pageIndex: Int, size: CGSize) -> UIImage? {
        PDFRenderer.shared.generateThumbnail(from: sourceURL, pageIndex: pageIndex, size: size)
    }
}
#endif
#endif
