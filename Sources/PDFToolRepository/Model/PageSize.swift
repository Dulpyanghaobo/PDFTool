//
//  PageSize.swift
//  PDFToolRepository
//
//  Paper size definitions
//

import Foundation
import CoreGraphics

private let mm2pt: CGFloat = 72.0 / 25.4

/// Unified paper size management
public enum PageSize: CaseIterable, Identifiable, Sendable {
    case original
    case a3
    case a4
    case a5
    case usLetter
    case usHalfLetter
    case usLegal
    case businessCard
    case idCard

    public var id: Self { self }

    /// Stable identifier for persistence (language-independent)
    public var code: String {
        switch self {
        case .original:     return "original"
        case .a3:           return "a3"
        case .a4:           return "a4"
        case .a5:           return "a5"
        case .usLetter:     return "us_letter"
        case .usHalfLetter: return "us_half"
        case .usLegal:      return "us_legal"
        case .businessCard: return "business_card"
        case .idCard:       return "id_card"
        }
    }

    /// Physical size in millimeters
    public var physical: CGSize {
        switch self {
        case .original:      return .zero
        case .a3:            return CGSize(width: 297, height: 420)
        case .a4:            return CGSize(width: 210, height: 297)
        case .a5:            return CGSize(width: 148, height: 210)
        case .usLetter:      return CGSize(width: 216, height: 279)
        case .usHalfLetter:  return CGSize(width: 140, height: 216)
        case .usLegal:       return CGSize(width: 216, height: 356)
        case .businessCard:  return CGSize(width: 90, height: 54)
        case .idCard:        return CGSize(width: 85.6, height: 53.98)
        }
    }

    /// Size in points (72 points = 1 inch)
    public var points: CGSize {
        guard self != .original else { return .zero }
        let p = physical
        return CGSize(width: p.width * mm2pt, height: p.height * mm2pt)
    }

    /// Aspect ratio (width/height)
    public var aspect: CGFloat {
        guard physical.width > 0, physical.height > 0 else { return 0.707 }
        return physical.width / physical.height
    }

    /// Display name for UI
    public var displayName: String {
        switch self {
        case .original:     return "Original"
        case .a3:           return "A3"
        case .a4:           return "A4"
        case .a5:           return "A5"
        case .usLetter:     return "US Letter"
        case .usHalfLetter: return "US Half Letter"
        case .usLegal:      return "US Legal"
        case .businessCard: return "Business Card"
        case .idCard:       return "ID Card"
        }
    }

    /// Dimension text like "210×297 mm"
    public var dimensionText: String {
        guard self != .original else { return "" }
        let w = Int(physical.width.rounded())
        let h = Int(physical.height.rounded())
        return "\(w)×\(h) mm"
    }
}

extension PageSize {
    /// Find by stable code (recommended)
    public static func from(code: String?) -> PageSize {
        guard let c = code?.lowercased() else { return .original }
        return PageSize.allCases.first { $0.code == c } ?? .original
    }

    /// Find by display name (legacy compatibility)
    public static func fromPaperName(_ v: String?) -> PageSize {
        if let v, let hit = PageSize.allCases.first(where: { $0.code == v.lowercased() }) {
            return hit
        }
        return PageSize.allCases.first { $0.displayName == v } ?? .original
    }
}