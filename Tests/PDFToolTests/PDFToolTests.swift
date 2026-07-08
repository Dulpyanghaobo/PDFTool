import XCTest
import PDFKit
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

    // MARK: - Facade Tests

    func testMergePDFsWritesDestinationWithCombinedPageCount() throws {
        let directory = try makeTemporaryDirectory()
        let first = directory.appendingPathComponent("first.pdf")
        let second = directory.appendingPathComponent("second.pdf")
        let merged = directory.appendingPathComponent("merged.pdf")
        try makePDF(at: first, pageCount: 2)
        try makePDF(at: second, pageCount: 3)

        let pageCount = try PDFTool.mergePDFs([first, second], to: merged)

        XCTAssertEqual(pageCount, 5)
        XCTAssertEqual(try PDFTool.pageCount(at: merged), 5)
    }

    func testSplitPDFWritesRequestedRanges() throws {
        let directory = try makeTemporaryDirectory()
        let source = directory.appendingPathComponent("source.pdf")
        try makePDF(at: source, pageCount: 5)

        let outputs = try PDFTool.splitPDF(
            at: source,
            pageRanges: [0..<2, 2..<5],
            outputDirectory: directory,
            baseName: "part"
        )

        XCTAssertEqual(outputs.count, 2)
        XCTAssertEqual(try PDFTool.pageCount(at: outputs[0]), 2)
        XCTAssertEqual(try PDFTool.pageCount(at: outputs[1]), 3)
    }

    func testAddTextAnnotationPersistsToPDF() throws {
        let directory = try makeTemporaryDirectory()
        let source = directory.appendingPathComponent("annotated.pdf")
        try makePDF(at: source, pageCount: 1)

        try PDFTool.addTextAnnotation(
            to: source,
            pageIndex: 0,
            bounds: CGRect(x: 10, y: 10, width: 60, height: 24),
            text: "Approved"
        )

        let document = try PDFTool.openDocument(at: source)
        let annotations = try XCTUnwrap(document.page(at: 0)?.annotations)
        XCTAssertEqual(annotations.count, 1)
        XCTAssertEqual(annotations.first?.contents, "Approved")
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func makePDF(at url: URL, pageCount: Int) throws {
        var mediaBox = CGRect(x: 0, y: 0, width: 100, height: 100)
        guard let consumer = CGDataConsumer(url: url as CFURL),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            XCTFail("Failed to create PDF test document")
            return
        }

        for _ in 0..<pageCount {
            context.beginPDFPage(nil)
            context.endPDFPage()
        }
        context.closePDF()
    }
}
