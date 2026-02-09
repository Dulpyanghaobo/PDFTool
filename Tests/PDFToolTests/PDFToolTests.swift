import XCTest
@testable import PDFTool

final class PDFToolTests: XCTestCase {
    
    // MARK: - PDFPageSize Tests
    
    func testPageSizePhysicalDimensions() {
        XCTAssertEqual(PDFPageSize.a4.physicalMM.width, 210)
        XCTAssertEqual(PDFPageSize.a4.physicalMM.height, 297)
        
        XCTAssertEqual(PDFPageSize.usLetter.physicalMM.width, 216)
        XCTAssertEqual(PDFPageSize.usLetter.physicalMM.height, 279)
        
        XCTAssertEqual(PDFPageSize.original.physicalMM, .zero)
    }
    
    func testPageSizePoints() {
        let a4Points = PDFPageSize.a4.points
        // 210mm * 72/25.4 ≈ 595.28
        XCTAssertEqual(a4Points.width, 210 * 72.0 / 25.4, accuracy: 0.01)
        XCTAssertEqual(a4Points.height, 297 * 72.0 / 25.4, accuracy: 0.01)
    }
    
    func testPageSizeAspect() {
        let a4Aspect = PDFPageSize.a4.aspect
        XCTAssertEqual(a4Aspect, 210.0 / 297.0, accuracy: 0.001)
        
        // Original should return default aspect
        XCTAssertEqual(PDFPageSize.original.aspect, 0.707, accuracy: 0.001)
    }
    
    func testPageSizeFromCode() {
        XCTAssertEqual(PDFPageSize.from(code: "a4"), .a4)
        XCTAssertEqual(PDFPageSize.from(code: "A4"), .a4)
        XCTAssertEqual(PDFPageSize.from(code: "usletter"), .usLetter)
        XCTAssertEqual(PDFPageSize.from(code: nil), .original)
        XCTAssertEqual(PDFPageSize.from(code: "invalid"), .original)
    }
    
    // MARK: - PDFPageRotation Tests
    
    func testPageRotationFromQuarterTurns() {
        XCTAssertEqual(PDFPageRotation.fromQuarterTurns(0), .none)
        XCTAssertEqual(PDFPageRotation.fromQuarterTurns(1), .clockwise90)
        XCTAssertEqual(PDFPageRotation.fromQuarterTurns(2), .clockwise180)
        XCTAssertEqual(PDFPageRotation.fromQuarterTurns(3), .clockwise270)
        XCTAssertEqual(PDFPageRotation.fromQuarterTurns(4), .none)
        XCTAssertEqual(PDFPageRotation.fromQuarterTurns(-1), .clockwise270)
    }
    
    // MARK: - PDFExportOptions Tests
    
    func testExportOptionsDefaults() {
        let options = PDFExportOptions()
        XCTAssertNil(options.pageOrder)
        XCTAssertNil(options.compressionQuality)
        XCTAssertNil(options.password)
        XCTAssertEqual(options.encryptionKeyLength, 128)
    }
    
    func testExportOptionsCustom() {
        let options = PDFExportOptions(
            pageOrder: [0, 2, 1],
            compressionQuality: 0.8,
            password: "secret",
            encryptionKeyLength: 256
        )
        XCTAssertEqual(options.pageOrder, [0, 2, 1])
        XCTAssertEqual(options.compressionQuality, 0.8)
        XCTAssertEqual(options.password, "secret")
        XCTAssertEqual(options.encryptionKeyLength, 256)
    }
    
    // MARK: - PDFToolError Tests
    
    func testErrorDescriptions() {
        let fileNotFound = PDFToolError.fileNotFound(URL(fileURLWithPath: "/test.pdf"))
        XCTAssertTrue(fileNotFound.errorDescription?.contains("test.pdf") ?? false)
        
        let pageError = PDFToolError.pageIndexOutOfRange(index: 5, count: 3)
        XCTAssertTrue(pageError.errorDescription?.contains("5") ?? false)
        XCTAssertTrue(pageError.errorDescription?.contains("3") ?? false)
    }
}