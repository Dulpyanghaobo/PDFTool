#if canImport(PDFKit)
import PDFKit
#endif
import Foundation
import CoreGraphics

#if canImport(UIKit)
import UIKit
#endif

/// Protocol for pages that can be exported
public protocol PDFExportablePage: Sendable {
    /// Get a UIImage representation of the page
    #if canImport(UIKit)
    func toUIImage() -> UIImage?
    #endif
    
    /// Get a PDFPage representation (for vector export)
    func toPDFPage() -> PDFPage?
}

/// Default implementation
public extension PDFExportablePage {
    func toPDFPage() -> PDFPage? { nil }
}

/// A PDF page that can be exported
public struct PDFExportablePageWrapper: PDFExportablePage {
    public let url: URL
    public let pageIndex: Int
    
    public init(url: URL, pageIndex: Int) {
        self.url = url
        self.pageIndex = pageIndex
    }
    
    public func toPDFPage() -> PDFPage? {
        guard let doc = PDFDocument(url: url) else { return nil }
        return doc.page(at: pageIndex)
    }
    
    #if canImport(UIKit)
    public func toUIImage() -> UIImage? {
        guard let doc = PDFDocument(url: url),
              let page = doc.page(at: pageIndex) else { return nil }
        
        let box = page.bounds(for: .mediaBox)
        let maxLong: CGFloat = 3508  // A4 @ 300dpi
        let scale = min(1, maxLong / max(box.width, box.height))
        let targetSize = CGSize(
            width: floor(box.width * scale),
            height: floor(box.height * scale)
        )
        
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: targetSize))
            let cg = ctx.cgContext
            cg.translateBy(x: 0, y: targetSize.height)
            cg.scaleBy(x: 1, y: -1)
            cg.scaleBy(x: targetSize.width / box.width, y: targetSize.height / box.height)
            page.draw(with: .mediaBox, to: cg)
        }
    }
    #endif
}

#if canImport(UIKit)
/// A UIImage that can be exported as a PDF page
public struct ImageExportablePage: PDFExportablePage {
    public let image: UIImage
    
    public init(image: UIImage) {
        self.image = image
    }
    
    public func toUIImage() -> UIImage? {
        return image
    }
    
    public func toPDFPage() -> PDFPage? {
        return PDFPage(image: image)
    }
}
#endif

/// Exports PDF documents with various options
public final class PDFExporter: @unchecked Sendable {
    
    // MARK: - Singleton
    
    public static let shared = PDFExporter()
    
    private init() {}
    
    // MARK: - Export to Data
    
    /// Export pages to PDF data
    /// - Parameters:
    ///   - pages: Pages to export
    ///   - options: Export options
    /// - Returns: PDF data
    public func exportToData(
        pages: [any PDFExportablePage],
        options: PDFExportOptions? = nil
    ) throws -> Data {
        let opts = options ?? PDFExportOptions()
        
        // If password is set, use CGContext for encryption
        if let password = opts.password, !password.isEmpty {
            return try exportEncryptedPDF(pages: pages, options: opts)
        }
        
        // Standard export without encryption
        let pdf = PDFDocument()
        for (idx, page) in pages.enumerated() {
            let allowed = opts.pageOrder == nil || opts.pageOrder!.contains(idx)
            guard allowed else { continue }
            
            if let vectorPage = page.toPDFPage() {
                pdf.insert(vectorPage, at: pdf.pageCount)
            } else {
                #if canImport(UIKit)
                if let img = page.toUIImage(), let rasterPage = PDFPage(image: img) {
                    pdf.insert(rasterPage, at: pdf.pageCount)
                }
                #endif
            }
        }
        
        guard let data = pdf.dataRepresentation() else {
            throw PDFToolError.exportFailed(reason: "Cannot get data representation")
        }
        return data
    }
    
    /// Export with encryption using CGContext
    private func exportEncryptedPDF(
        pages: [any PDFExportablePage],
        options: PDFExportOptions
    ) throws -> Data {
        let out = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: 595, height: 842) // A4 default
        
        guard let consumer = CGDataConsumer(data: out as CFMutableData) else {
            throw PDFToolError.exportFailed(reason: "Cannot create data consumer")
        }
        
        var pdfOptions: [CFString: Any] = [:]
        if let pwd = options.password, !pwd.isEmpty {
            pdfOptions[kCGPDFContextUserPassword] = pwd
            pdfOptions[kCGPDFContextOwnerPassword] = pwd
            pdfOptions[kCGPDFContextEncryptionKeyLength] = options.encryptionKeyLength
        }
        
        guard let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, pdfOptions as CFDictionary) else {
            throw PDFToolError.exportFailed(reason: "Cannot create PDF context")
        }
        
        for (idx, page) in pages.enumerated() {
            let allowed = options.pageOrder == nil || options.pageOrder!.contains(idx)
            guard allowed else { continue }
            
            try autoreleasepool {
                // Try vector page first
                if let pdfPage = page.toPDFPage(), let cgPage = pdfPage.pageRef {
                    let box = cgPage.getBoxRect(.mediaBox)
                    let rect = CGRect(origin: .zero, size: box.size)
                    ctx.beginPDFPage([kCGPDFContextMediaBox as String: rect] as CFDictionary)
                    ctx.saveGState()
                    ctx.translateBy(x: -box.origin.x, y: -box.origin.y)
                    ctx.drawPDFPage(cgPage)
                    ctx.restoreGState()
                    ctx.endPDFPage()
                    return
                }
                
                #if canImport(UIKit)
                // Fallback to raster
                if let ui = page.toUIImage() {
                    let pxW = ui.size.width * ui.scale
                    let pxH = ui.size.height * ui.scale
                    let maxLong: CGFloat = 3508
                    let scaleFactor = min(1, maxLong / max(pxW, pxH))
                    let drawSize = CGSize(
                        width: floor(pxW * scaleFactor),
                        height: floor(pxH * scaleFactor)
                    )
                    
                    let fmt = UIGraphicsImageRendererFormat.default()
                    fmt.opaque = true
                    fmt.scale = 1
                    let rendered = UIGraphicsImageRenderer(size: drawSize, format: fmt).image { _ in
                        ui.draw(in: CGRect(origin: .zero, size: drawSize))
                    }
                    guard let cg = rendered.cgImage else {
                        throw PDFToolError.invalidImage
                    }
                    
                    let rect = CGRect(origin: .zero, size: drawSize)
                    ctx.beginPDFPage([kCGPDFContextMediaBox as String: rect] as CFDictionary)
                    ctx.saveGState()
                    ctx.translateBy(x: 0, y: rect.height)
                    ctx.scaleBy(x: 1, y: -1)
                    ctx.draw(cg, in: rect)
                    ctx.restoreGState()
                    ctx.endPDFPage()
                    return
                }
                #endif
                
                throw PDFToolError.exportFailed(reason: "Page has no valid content")
            }
        }
        
        ctx.closePDF()
        return out as Data
    }
    
    // MARK: - Export to File
    
    /// Export pages to a PDF file
    /// - Parameters:
    ///   - pages: Pages to export
    ///   - url: Destination URL
    ///   - options: Export options
    public func exportToFile(
        pages: [any PDFExportablePage],
        url: URL,
        options: PDFExportOptions? = nil
    ) throws {
        let data = try exportToData(pages: pages, options: options)
        
        let fm = FileManager.default
        let dir = url.deletingLastPathComponent()
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }
    
    /// Write pages to a PDF file using streaming (memory efficient)
    /// - Parameters:
    ///   - pages: Pages to export
    ///   - url: Destination URL
    ///   - options: Export options
    public func streamToFile(
        pages: [any PDFExportablePage],
        url: URL,
        options: PDFExportOptions? = nil
    ) throws {
        let opts = options ?? PDFExportOptions()
        var mediaBox = CGRect(x: 0, y: 0, width: 595, height: 842)
        
        guard let consumer = CGDataConsumer(url: url as CFURL) else {
            throw PDFToolError.exportFailed(reason: "Cannot create file consumer")
        }
        
        var ctxOptions: [CFString: Any] = [:]
        if let pwd = opts.password, !pwd.isEmpty {
            ctxOptions[kCGPDFContextUserPassword] = pwd
            ctxOptions[kCGPDFContextOwnerPassword] = pwd
            ctxOptions[kCGPDFContextEncryptionKeyLength] = opts.encryptionKeyLength
        }
        
        guard let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, ctxOptions as CFDictionary) else {
            throw PDFToolError.exportFailed(reason: "Cannot create PDF context")
        }
        
        for (idx, page) in pages.enumerated() {
            let allowed = opts.pageOrder == nil || opts.pageOrder!.contains(idx)
            guard allowed else { continue }
            
            try autoreleasepool {
                // Vector page
                if let pdfPage = page.toPDFPage(), let cgPage = pdfPage.pageRef {
                    let box = cgPage.getBoxRect(.mediaBox)
                    let rect = CGRect(origin: .zero, size: box.size)
                    ctx.beginPDFPage([kCGPDFContextMediaBox as String: rect] as CFDictionary)
                    ctx.saveGState()
                    ctx.translateBy(x: -box.origin.x, y: -box.origin.y)
                    ctx.drawPDFPage(cgPage)
                    ctx.restoreGState()
                    ctx.endPDFPage()
                    return
                }
                
                #if canImport(UIKit)
                // Raster page
                if let ui = page.toUIImage() {
                    let pxW = ui.size.width * ui.scale
                    let pxH = ui.size.height * ui.scale
                    let maxLong: CGFloat = 3508
                    let scaleFactor = min(1, maxLong / max(pxW, pxH))
                    let drawSize = CGSize(
                        width: floor(pxW * scaleFactor),
                        height: floor(pxH * scaleFactor)
                    )
                    
                    let fmt = UIGraphicsImageRendererFormat.default()
                    fmt.opaque = true
                    fmt.scale = 1
                    let rendered = UIGraphicsImageRenderer(size: drawSize, format: fmt).image { _ in
                        ui.draw(in: CGRect(origin: .zero, size: drawSize))
                    }
                    guard let cg = rendered.cgImage else {
                        throw PDFToolError.invalidImage
                    }
                    
                    let rect = CGRect(origin: .zero, size: drawSize)
                    ctx.beginPDFPage([kCGPDFContextMediaBox as String: rect] as CFDictionary)
                    ctx.saveGState()
                    ctx.translateBy(x: 0, y: rect.height)
                    ctx.scaleBy(x: 1, y: -1)
                    ctx.draw(cg, in: rect)
                    ctx.restoreGState()
                    ctx.endPDFPage()
                    return
                }
                #endif
                
                throw PDFToolError.exportFailed(reason: "Page has no valid content")
            }
        }
        
        ctx.closePDF()
    }
    
    // MARK: - Convenience Methods
    
    /// Export a PDF document to a new file with optional encryption
    /// - Parameters:
    ///   - sourceURL: Source PDF URL
    ///   - destinationURL: Destination URL
    ///   - options: Export options
    public func exportDocument(
        from sourceURL: URL,
        to destinationURL: URL,
        options: PDFExportOptions? = nil
    ) throws {
        guard let document = PDFDocument(url: sourceURL) else {
            throw PDFToolError.invalidPDF(sourceURL)
        }
        
        var pages: [PDFExportablePageWrapper] = []
        for i in 0..<document.pageCount {
            pages.append(PDFExportablePageWrapper(url: sourceURL, pageIndex: i))
        }
        
        try exportToFile(pages: pages, url: destinationURL, options: options)
    }
    
    #if canImport(UIKit)
    /// Export UIImages to a PDF file
    /// - Parameters:
    ///   - images: Images to export
    ///   - url: Destination URL
    ///   - options: Export options
    public func exportImages(
        _ images: [UIImage],
        to url: URL,
        options: PDFExportOptions? = nil
    ) throws {
        let pages = images.map { ImageExportablePage(image: $0) }
        try exportToFile(pages: pages, url: url, options: options)
    }
    #endif
}

// MARK: - JPEG Export

#if canImport(UIKit)
public extension PDFExporter {
    
    /// Export pages as JPEG images
    /// - Parameters:
    ///   - pages: Pages to export
    ///   - quality: JPEG quality (0.0 - 1.0)
    /// - Returns: Array of JPEG data
    func exportToJPEG(
        pages: [any PDFExportablePage],
        quality: CGFloat = 0.9
    ) throws -> [Data] {
        var results: [Data] = []
        for page in pages {
            guard let image = page.toUIImage(),
                  let data = image.jpegData(compressionQuality: quality) else {
                throw PDFToolError.exportFailed(reason: "Cannot convert page to JPEG")
            }
            results.append(data)
        }
        return results
    }
    
    /// Export pages as JPEG files
    /// - Parameters:
    ///   - pages: Pages to export
    ///   - directory: Destination directory
    ///   - baseName: Base name for files (will be appended with index)
    ///   - quality: JPEG quality (0.0 - 1.0)
    /// - Returns: Array of file URLs
    func exportToJPEGFiles(
        pages: [any PDFExportablePage],
        directory: URL,
        baseName: String = "page",
        quality: CGFloat = 0.9
    ) throws -> [URL] {
        let fm = FileManager.default
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        
        var urls: [URL] = []
        for (index, page) in pages.enumerated() {
            guard let image = page.toUIImage(),
                  let data = image.jpegData(compressionQuality: quality) else {
                throw PDFToolError.exportFailed(reason: "Cannot convert page to JPEG")
            }
            
            let url = directory.appendingPathComponent("\(baseName)-\(index + 1).jpg")
            try data.write(to: url, options: .atomic)
            urls.append(url)
        }
        return urls
    }
}
#endif