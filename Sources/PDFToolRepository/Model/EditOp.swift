//
//  EditOp.swift
//  PDFToolRepository
//
//  Edit operation types for tracking document changes
//

import Foundation
import CoreGraphics

// MARK: - EditOp
public struct EditOp: Codable, Hashable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case crop
        case resize
        case filter
        case watermark
        case signature
        case addPages
    }

    public var kind: Kind
    public var params: Data

    public init(kind: Kind, params: Data) {
        self.kind = kind
        self.params = params
    }
}

// MARK: - Filter Type
public enum FilterType: String, CaseIterable, Identifiable, Codable, Sendable {
    case color = "Color"
    case gray = "GrayScale"
    case bw = "B&W"
    case photo = "Photo"

    public var id: Self { self }
    public var title: String { rawValue }

    /// Loose parsing: compatible with aliases and case-insensitive
    public init?(persisted raw: String) {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch s {
        case "photo": self = .photo
        case "color", "colour": self = .color
        case "grayscale", "gray", "grey", "gray-scale", "grey-scale": self = .gray
        case "b&w", "bw", "b/w", "blackwhite", "black-white": self = .bw
        default:
            self.init(rawValue: raw)
        }
    }
}

// MARK: - Payloads
private struct FitToPagePayload: Codable {
    let size: String
    let addWhiteEdge: Bool
    let pageIndexes: [Int]?
}

private struct RotatePayload: Codable {
    let angle: Int
    let pageIndex: Int
}

private struct FilterPayload: Codable {
    let filter: String
    let pageIndex: Int
}

private struct CustomCropPayload: Codable {
    let rects: [CGRect]
    let addWhiteEdge: Bool
    let pageIndexes: [Int]
}

private struct QuadPayload: Codable {
    let tl: [CGFloat]
    let tr: [CGFloat]
    let br: [CGFloat]
    let bl: [CGFloat]
    let pageIndex: Int
}

private struct SignatureInsertPayload: Codable {
    let pageIndex: Int
    let count: Int
}

// MARK: - Factory Helpers
extension EditOp {

    /// Scale/center by paper size with optional white edge
    public static func fitToPage(size: PageSize,
                                  addWhiteEdge: Bool,
                                  pageIndexes: [Int]? = nil) -> Self {
        let payload = FitToPagePayload(size: size.displayName,
                                        addWhiteEdge: addWhiteEdge,
                                        pageIndexes: pageIndexes)
        return .init(kind: .resize,
                     params: try! JSONEncoder().encode(payload))
    }

    /// Custom crop (batch multiple pages)
    public static func customCrop(rects: [CGRect],
                                   pageIndexes: [Int],
                                   addWhiteEdge: Bool = false) -> Self {
        precondition(rects.count == pageIndexes.count,
                     "rects.count must match pageIndexes.count")
        let payload = CustomCropPayload(rects: rects,
                                         addWhiteEdge: addWhiteEdge,
                                         pageIndexes: pageIndexes)
        return .init(kind: .crop,
                     params: try! JSONEncoder().encode(payload))
    }

    public static func rotate90CW(pageIndex: Int) -> Self {
        let payload = RotatePayload(angle: 90, pageIndex: pageIndex)
        return .init(kind: .resize,
                     params: try! JSONEncoder().encode(payload))
    }

    public static func applyFilter(filter: FilterType,
                                    pageIndex: Int) -> Self {
        let payload = FilterPayload(filter: filter.rawValue,
                                     pageIndex: pageIndex)
        return .init(kind: .filter,
                     params: try! JSONEncoder().encode(payload))
    }

    /// Record perspective crop with quad
    public static func perspectiveCrop(quad: Quad, pageIndex: Int) -> Self {
        let payload = QuadPayload(
            tl: [quad.tl.x, quad.tl.y],
            tr: [quad.tr.x, quad.tr.y],
            br: [quad.br.x, quad.br.y],
            bl: [quad.bl.x, quad.bl.y],
            pageIndex: pageIndex
        )
        return .init(kind: .crop,
                     params: try! JSONEncoder().encode(payload))
    }

    /// Record signature insertion
    public static func signatureInsert(pageIndex: Int, count: Int) -> Self {
        let payload = SignatureInsertPayload(pageIndex: pageIndex, count: count)
        return .init(kind: .signature,
                     params: try! JSONEncoder().encode(payload))
    }

    public func parsedFilter() -> (filter: FilterType, pageIndex: Int)? {
        guard kind == .filter,
              let payload = try? JSONDecoder().decode(FilterPayload.self, from: params),
              let ft = FilterType(rawValue: payload.filter) else { return nil }
        return (ft, payload.pageIndex)
    }
}

// MARK: - Quad
public struct Quad: Codable, Hashable, Sendable {
    public var tl: CGPoint
    public var tr: CGPoint
    public var br: CGPoint
    public var bl: CGPoint

    public init(tl: CGPoint, tr: CGPoint, br: CGPoint, bl: CGPoint) {
        self.tl = tl
        self.tr = tr
        self.br = br
        self.bl = bl
    }

    public static let zero = Quad(tl: .zero, tr: .zero, br: .zero, bl: .zero)
}