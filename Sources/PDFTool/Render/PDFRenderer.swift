#if canImport(PDFKit)
import PDFKit
#endif
import Foundation
import CoreGraphics

#if canImport(UIKit)
import UIKit
#endif

/// Renders PDF pages to images and handles visual operations
public final class PDFRenderer: @unchecked Sendable {
    
    // MARK: - Singleton
    
    public static let shared = PDFRenderer()
    
    private init() {}
    
    // MARK: - Page Rendering
    
    #if canImport(UIKit)
    /// Render a PDF page to a UIImage
    /// - Parameters:
    ///   - page: The PDF page to render
    ///   - maxLongSide: Maximum length of the longer side in pixels
    ///   - backgroundColor: Background color (default: white)
    /// - Returns: Rendered UIImage
    public func renderPage(
        _ page: PDFPage,
        maxLongSide: CGFloat = 2000,
        backgroundColor: UIColor = .white
    ) -> UIImage? {
        let box = page.bounds(for: .mediaBox)
        let scale = min(1, maxLongSide / max(box.width, box.height))
        let targetSize = CGSize(
            width: floor(box.width * scale),
            height: floor(box.height * scale)
        )
        
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { ctx in
            backgroundColor.setFill()
            ctx.fill(CGRect(origin: .zero, size: targetSize))
            
            let cg = ctx.cgContext
            cg.translateBy(x: 0, y: targetSize.height)
            cg.scaleBy(x: 1, y: -1)
            cg.scaleBy(x: targetSize.width / box.width, y: targetSize.height / box.height)
            page.draw(with: .mediaBox, to: cg)
        }
    }
    
    /// Render a PDF page from a document URL
    /// - Parameters:
    ///   - url: URL of the PDF file
    ///   - pageIndex: Index of the page to render (0-based)
    ///   - maxLongSide: Maximum length of the longer side in pixels
    /// - Returns: Rendered UIImage
    public func renderPage(
        from url: URL,
        pageIndex: Int,
        maxLongSide: CGFloat = 2000
    ) -> UIImage? {
        guard let document = PDFDocument(url: url),
              let page = document.page(at: pageIndex) else {
            return nil
        }
        return renderPage(page, maxLongSide: maxLongSide)
    }
    
    /// Render a PDF page to a CGImage
    /// - Parameters:
    ///   - url: URL of the PDF file
    ///   - pageIndex: Index of the page to render (0-based)
    ///   - maxLongSide: Maximum length of the longer side in pixels
    /// - Returns: Rendered CGImage
    public func renderPageToCGImage(
        from url: URL,
        pageIndex: Int,
        maxLongSide: CGFloat = 2000
    ) -> CGImage? {
        return renderPage(from: url, pageIndex: pageIndex, maxLongSide: maxLongSide)?.cgImage
    }
    
    /// Render all pages of a PDF to images
    /// - Parameters:
    ///   - url: URL of the PDF file
    ///   - maxLongSide: Maximum length of the longer side in pixels
    /// - Returns: Array of rendered UIImages
    public func renderAllPages(
        from url: URL,
        maxLongSide: CGFloat = 2000
    ) -> [UIImage] {
        guard let document = PDFDocument(url: url) else {
            return []
        }
        
        var images: [UIImage] = []
        for i in 0..<document.pageCount {
            if let page = document.page(at: i),
               let image = renderPage(page, maxLongSide: maxLongSide) {
                images.append(image)
            }
        }
        return images
    }
    #endif
    
    // MARK: - Thumbnail Generation
    
    #if canImport(UIKit)
    /// Generate a thumbnail for a PDF page
    /// - Parameters:
    ///   - page: The PDF page
    ///   - size: Target thumbnail size
    /// - Returns: Thumbnail UIImage
    public func generateThumbnail(
        for page: PDFPage,
        size: CGSize
    ) -> UIImage? {
        let box = page.bounds(for: .mediaBox)
        let aspect = box.width / box.height
        
        var targetSize = size
        if aspect > 1 {
            targetSize.height = size.width / aspect
        } else {
            targetSize.width = size.height * aspect
        }
        
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
    
    /// Generate a thumbnail for a PDF page from a URL
    /// - Parameters:
    ///   - url: URL of the PDF file
    ///   - pageIndex: Index of the page (0-based)
    ///   - size: Target thumbnail size
    /// - Returns: Thumbnail UIImage
    public func generateThumbnail(
        from url: URL,
        pageIndex: Int,
        size: CGSize
    ) -> UIImage? {
        guard let document = PDFDocument(url: url),
              let page = document.page(at: pageIndex) else {
            return nil
        }
        return generateThumbnail(for: page, size: size)
    }
    #endif
    
    // MARK: - Page Info
    
    /// Get the bounds of a PDF page
    /// - Parameters:
    ///   - url: URL of the PDF file
    ///   - pageIndex: Index of the page (0-based)
    ///   - box: PDF box type to use
    /// - Returns: Page bounds as CGRect
    public func pageBounds(
        from url: URL,
        pageIndex: Int,
        box: CGPDFBox = .mediaBox
    ) -> CGRect? {
        guard let document = PDFDocument(url: url),
              let page = document.page(at: pageIndex) else {
            return nil
        }
        return page.bounds(for: PDFDisplayBox(rawValue: Int(box.rawValue)) ?? .mediaBox)
    }
    
    /// Get the rotation of a PDF page
    /// - Parameters:
    ///   - url: URL of the PDF file
    ///   - pageIndex: Index of the page (0-based)
    /// - Returns: Rotation angle in degrees (0, 90, 180, or 270)
    public func pageRotation(
        from url: URL,
        pageIndex: Int
    ) -> Int? {
        guard let document = PDFDocument(url: url),
              let page = document.page(at: pageIndex) else {
            return nil
        }
        return page.rotation
    }
}

// MARK: - CoreGraphics Rendering

public extension PDFRenderer {
    
    /// Render a PDF page using CoreGraphics directly
    /// - Parameters:
    ///   - cgPDFPage: The CGPDFPage to render
    ///   - size: Target size
    ///   - backgroundColor: Background color
    /// - Returns: CGImage
    func renderCGPDFPage(
        _ cgPDFPage: CGPDFPage,
        size: CGSize,
        backgroundColor: CGColor? = CGColor(gray: 1, alpha: 1)
    ) -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        
        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return nil
        }
        
        // Fill background
        if let bg = backgroundColor {
            context.setFillColor(bg)
            context.fill(CGRect(origin: .zero, size: size))
        }
        
        // Calculate scaling
        let box = cgPDFPage.getBoxRect(.mediaBox)
        let scaleX = size.width / box.width
        let scaleY = size.height / box.height
        let scale = min(scaleX, scaleY)
        
        // Center the content
        let drawWidth = box.width * scale
        let drawHeight = box.height * scale
        let offsetX = (size.width - drawWidth) / 2
        let offsetY = (size.height - drawHeight) / 2
        
        context.saveGState()
        context.translateBy(x: offsetX, y: offsetY)
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: -box.minX, y: -box.minY)
        context.drawPDFPage(cgPDFPage)
        context.restoreGState()
        
        return context.makeImage()
    }
}