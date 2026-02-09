import Foundation
import CoreGraphics

// MARK: - Page Size

/// Standard paper sizes for PDF documents
public enum PDFPageSize: String, CaseIterable, Identifiable, Sendable {
    case original
    case a3
    case a4
    case a5
    case usLetter
    case usHalfLetter
    case usLegal
    case businessCard
    case idCard
    
    public var id: String { rawValue }
    
    /// Physical dimensions in millimeters
    public var physicalMM: CGSize {
        switch self {
        case .original:      return .zero
        case .a3:            return CGSize(width: 297,  height: 420)
        case .a4:            return CGSize(width: 210,  height: 297)
        case .a5:            return CGSize(width: 148,  height: 210)
        case .usLetter:      return CGSize(width: 216,  height: 279)
        case .usHalfLetter:  return CGSize(width: 140,  height: 216)
        case .usLegal:       return CGSize(width: 216,  height: 356)
        case .businessCard:  return CGSize(width: 90,   height: 54)
        case .idCard:        return CGSize(width: 85.6, height: 53.98)
        }
    }
    
    /// Dimensions in points (72 points per inch)
    public var points: CGSize {
        guard self != .original else { return .zero }
        let mm = physicalMM
        let mm2pt: CGFloat = 72.0 / 25.4
        return CGSize(width: mm.width * mm2pt, height: mm.height * mm2pt)
    }
    
    /// Aspect ratio (width / height)
    public var aspect: CGFloat {
        guard physicalMM.width > 0, physicalMM.height > 0 else { return 0.707 }
        return physicalMM.width / physicalMM.height
    }
    
    /// Create from a code string
    public static func from(code: String?) -> PDFPageSize {
        guard let c = code?.lowercased() else { return .original }
        return PDFPageSize.allCases.first { $0.rawValue.lowercased() == c } ?? .original
    }
}

// MARK: - Resize Mode

/// Mode for resizing content when applying page sizes
public enum PDFResizeMode: Sendable {
    case fit           // Fit content within bounds, maintaining aspect ratio
    case fill          // Fill bounds, may crop content
    case stretch       // Stretch to fill, may distort
    case keepScaleCenter  // Keep original scale, center in bounds
}

// MARK: - PDF Variant

/// Different variants of a PDF document
public enum PDFVariant: String, Sendable {
    case working    // The current working copy
    case original   // The original imported version
    case cropped    // A cropped version
}

// MARK: - Export Options

/// Options for exporting PDF documents
public struct PDFExportOptions: Sendable {
    /// Specific page indices to export (nil = all pages)
    public var pageOrder: [Int]?
    
    /// JPEG compression quality (0.0 - 1.0) for raster images
    public var compressionQuality: CGFloat?
    
    /// Password for encrypted PDF
    public var password: String?
    
    /// Encryption key length (128 or 256)
    public var encryptionKeyLength: Int
    
    public init(
        pageOrder: [Int]? = nil,
        compressionQuality: CGFloat? = nil,
        password: String? = nil,
        encryptionKeyLength: Int = 128
    ) {
        self.pageOrder = pageOrder
        self.compressionQuality = compressionQuality
        self.password = password
        self.encryptionKeyLength = encryptionKeyLength
    }
}

// MARK: - Errors

/// Errors that can occur during PDF operations
public enum PDFToolError: Error, LocalizedError, Sendable {
    case fileNotFound(URL)
    case invalidPDF(URL)
    case cannotOpenPDF(URL)
    case cannotCreatePDF
    case cannotWritePDF(URL)
    case pageIndexOutOfRange(index: Int, count: Int)
    case invalidImage
    case exportFailed(reason: String)
    case operationCancelled
    case ioError(String)
    
    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let url):
            return "File not found: \(url.lastPathComponent)"
        case .invalidPDF(let url):
            return "Invalid PDF file: \(url.lastPathComponent)"
        case .cannotOpenPDF(let url):
            return "Cannot open PDF: \(url.lastPathComponent)"
        case .cannotCreatePDF:
            return "Cannot create PDF document"
        case .cannotWritePDF(let url):
            return "Cannot write PDF to: \(url.lastPathComponent)"
        case .pageIndexOutOfRange(let index, let count):
            return "Page index \(index) out of range (0..<\(count))"
        case .invalidImage:
            return "Invalid image data"
        case .exportFailed(let reason):
            return "Export failed: \(reason)"
        case .operationCancelled:
            return "Operation was cancelled"
        case .ioError(let message):
            return "I/O error: \(message)"
        }
    }
}

// MARK: - Page Rotation

/// Represents a rotation in 90-degree increments
public enum PDFPageRotation: Int, Sendable {
    case none = 0
    case clockwise90 = 90
    case clockwise180 = 180
    case clockwise270 = 270
    
    /// Create from quarter turns (positive = clockwise)
    public static func fromQuarterTurns(_ turns: Int) -> PDFPageRotation {
        let normalized = ((turns % 4) + 4) % 4
        switch normalized {
        case 0: return .none
        case 1: return .clockwise90
        case 2: return .clockwise180
        case 3: return .clockwise270
        default: return .none
        }
    }
    
    /// Number of quarter turns
    public var quarterTurns: Int {
        rawValue / 90
    }
}