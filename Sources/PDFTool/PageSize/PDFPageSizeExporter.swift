#if canImport(PDFKit)
import PDFKit
#endif
import Foundation
import CoreGraphics

#if canImport(UIKit)
import UIKit
#endif

/// Exports PDF with custom page sizes
public final class PDFPageSizeExporter: @unchecked Sendable {
    
    // MARK: - Singleton
    
    public static let shared = PDFPageSizeExporter()
    
    private init() {}
    
    // MARK: - Export with Page Sizes
    
    /// Export a PDF with custom page sizes applied to each page
    /// - Parameters:
    ///   - inputURL: Source PDF URL
    ///   - outputURL: Destination URL
    ///   - pageSizes: Dictionary mapping page index to page size
    ///   - mode: Resize mode
    ///   - backgroundColor: Background color
    ///   - useBox: PDF box type to use for source dimensions
    public func export(
        inputURL: URL,
        outputURL: URL,
        pageSizes: [Int: PDFPageSize],
        mode: PDFResizeMode = .fit,
        backgroundColor: CGColor? = CGColor(gray: 1, alpha: 1),
        useBox: CGPDFBox = .cropBox
    ) throws {
        guard let src = CGPDFDocument(inputURL as CFURL) else {
            throw PDFToolError.cannotOpenPDF(inputURL)
        }
        
        let count = src.numberOfPages
        guard count > 0 else { return }
        
        // Ensure output directory exists
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        
        guard let consumer = CGDataConsumer(url: outputURL as CFURL) else {
            throw PDFToolError.cannotWritePDF(outputURL)
        }
        
        var media = CGRect(x: 0, y: 0, width: 100, height: 100)
        guard let ctx = CGContext(consumer: consumer, mediaBox: &media, nil) else {
            throw PDFToolError.exportFailed(reason: "Cannot create PDF context")
        }
        
        for i in 0..<count {
            guard let page = src.page(at: i + 1) else { continue }
            let srcBox = page.getBoxRect(useBox)
            
            // Calculate target size
            let selected = pageSizes[i] ?? .original
            let targetSize = calculateTargetSize(for: selected, sourceBox: srcBox)
            
            var pageBox = CGRect(origin: .zero, size: targetSize)
            ctx.beginPage(mediaBox: &pageBox)
            
            // Fill background
            if let bg = backgroundColor {
                ctx.setFillColor(bg)
                ctx.fill(pageBox)
            }
            
            // Calculate scaling and offset
            let (scale, offset) = calculateScaleAndOffset(
                sourceBox: srcBox,
                targetSize: targetSize,
                mode: mode
            )
            
            // Draw the page
            ctx.saveGState()
            ctx.translateBy(x: offset.x, y: offset.y)
            ctx.scaleBy(x: scale.width, y: scale.height)
            ctx.translateBy(x: -srcBox.minX, y: -srcBox.minY)
            ctx.drawPDFPage(page)
            ctx.restoreGState()
            
            ctx.endPage()
        }
        
        ctx.closePDF()
    }
    
    // MARK: - Calculate Target Size
    
    private func calculateTargetSize(for pageSize: PDFPageSize, sourceBox: CGRect) -> CGSize {
        if pageSize == .original {
            return CGSize(width: max(1, sourceBox.width), height: max(1, sourceBox.height))
        }
        
        let aspect = pageSize.aspect
        let imgAspect = sourceBox.width / sourceBox.height
        let portrait = aspect
        let landscape = 1 / aspect
        
        // Choose orientation that matches the image better
        let pick = abs(imgAspect - landscape) < abs(imgAspect - portrait) ? landscape : portrait
        let pts = pageSize.points
        
        return pick == portrait
            ? pts
            : CGSize(width: pts.height, height: pts.width)
    }
    
    // MARK: - Calculate Scale and Offset
    
    private func calculateScaleAndOffset(
        sourceBox: CGRect,
        targetSize: CGSize,
        mode: PDFResizeMode
    ) -> (scale: CGSize, offset: CGPoint) {
        let sx0 = targetSize.width / sourceBox.width
        let sy0 = targetSize.height / sourceBox.height
        
        let (sx, sy): (CGFloat, CGFloat) = {
            switch mode {
            case .fit:
                let s = min(sx0, sy0)
                return (s, s)
            case .fill:
                let s = max(sx0, sy0)
                return (s, s)
            case .stretch:
                return (sx0, sy0)
            case .keepScaleCenter:
                return (1, 1)
            }
        }()
        
        let drawSize = CGSize(width: sourceBox.width * sx, height: sourceBox.height * sy)
        let offset = CGPoint(
            x: (targetSize.width - drawSize.width) * 0.5,
            y: (targetSize.height - drawSize.height) * 0.5
        )
        
        return (CGSize(width: sx, height: sy), offset)
    }
}

// MARK: - PDFDocument Extension

public extension PDFPageSizeExporter {
    
    /// Apply page sizes to a PDFDocument in place
    /// - Parameters:
    ///   - document: The PDF document
    ///   - pageSizes: Dictionary mapping page index to page size
    ///   - mode: Resize mode
    #if canImport(UIKit)
    func applyPageSizes(
        to document: PDFDocument,
        pageSizes: [Int: PDFPageSize],
        mode: PDFResizeMode = .fit
    ) throws {
        // This requires creating a temporary file, processing it, then loading it back
        let tempDir = FileManager.default.temporaryDirectory
        let inputURL = tempDir.appendingPathComponent("input-\(UUID().uuidString).pdf")
        let outputURL = tempDir.appendingPathComponent("output-\(UUID().uuidString).pdf")
        
        defer {
            try? FileManager.default.removeItem(at: inputURL)
            try? FileManager.default.removeItem(at: outputURL)
        }
        
        // Save current document
        guard document.write(to: inputURL) else {
            throw PDFToolError.cannotWritePDF(inputURL)
        }
        
        // Apply page sizes
        try export(inputURL: inputURL, outputURL: outputURL, pageSizes: pageSizes, mode: mode)
        
        // Load result back
        guard let result = PDFDocument(url: outputURL) else {
            throw PDFToolError.invalidPDF(outputURL)
        }
        
        // Replace pages in original document
        while document.pageCount > 0 {
            document.removePage(at: 0)
        }
        for i in 0..<result.pageCount {
            if let page = result.page(at: i) {
                document.insert(page, at: document.pageCount)
            }
        }
    }
    #endif
}

// MARK: - UIGraphics PDF Rendering

#if canImport(UIKit)
public extension PDFPageSizeExporter {
    
    /// Render a PDF document with page sizes using UIKit (for compatibility)
    /// - Parameters:
    ///   - document: Source PDF document
    ///   - pageSizes: Dictionary mapping page index to page size
    ///   - outputURL: Destination URL
    func renderWithUIKit(
        document: PDFDocument,
        pageSizes: [Int: PDFPageSize],
        to outputURL: URL
    ) throws {
        let defaultA4 = CGRect(x: 0, y: 0, width: 595, height: 842)
        let fmt = UIGraphicsPDFRendererFormat()
        let renderer = UIGraphicsPDFRenderer(bounds: defaultA4, format: fmt)
        
        try renderer.writePDF(to: outputURL) { ctx in
            for i in 0..<document.pageCount {
                guard let page = document.page(at: i) else { continue }
                
                let selected = pageSizes[i] ?? .original
                let srcBox = page.bounds(for: .mediaBox)
                
                let targetSizePt: CGSize = {
                    if selected == .original {
                        return srcBox.size
                    }
                    let mm = selected.physicalMM
                    return CGSize(
                        width: mm.width * 72.0 / 25.4,
                        height: mm.height * 72.0 / 25.4
                    )
                }()
                
                let pageRect = CGRect(origin: .zero, size: targetSizePt)
                ctx.beginPage(withBounds: pageRect, pageInfo: [:])
                
                UIColor.white.setFill()
                ctx.cgContext.fill(pageRect)
                
                // Calculate scale and center
                let sx = targetSizePt.width / max(1, srcBox.width)
                let sy = targetSizePt.height / max(1, srcBox.height)
                let s = min(sx, sy)
                let drawW = srcBox.width * s
                let drawH = srcBox.height * s
                let drawX = (targetSizePt.width - drawW) / 2
                let drawY = (targetSizePt.height - drawH) / 2
                
                ctx.cgContext.saveGState()
                ctx.cgContext.translateBy(x: drawX, y: drawY)
                ctx.cgContext.scaleBy(x: s, y: s)
                page.draw(with: .mediaBox, to: ctx.cgContext)
                ctx.cgContext.restoreGState()
            }
        }
    }
}
#endif
