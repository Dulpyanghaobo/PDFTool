// PDFTool - Public API Exports
// This file re-exports all public types for convenient access

// Core Types
@_exported import struct Foundation.URL
@_exported import struct Foundation.Data
@_exported import struct Foundation.UUID
@_exported import struct CoreGraphics.CGSize
@_exported import struct CoreGraphics.CGPoint
@_exported import struct CoreGraphics.CGRect
@_exported import struct CoreGraphics.CGFloat

// Re-export PDFKit for convenience
#if canImport(PDFKit)
@_exported import PDFKit
#endif