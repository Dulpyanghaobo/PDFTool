//
//  PDFToolRepositoryTests.swift
//  PDFToolRepositoryTests
//

import XCTest
@testable import PDFToolRepository

final class PDFToolRepositoryTests: XCTestCase {
    
    func testPageSizeCode() {
        XCTAssertEqual(PageSize.a4.code, "a4")
        XCTAssertEqual(PageSize.usLetter.code, "us_letter")
        XCTAssertEqual(PageSize.from(code: "a4"), .a4)
        XCTAssertEqual(PageSize.from(code: "original"), .original)
    }
    
    func testPageSizePhysical() {
        let a4 = PageSize.a4.physical
        XCTAssertEqual(a4.width, 210)
        XCTAssertEqual(a4.height, 297)
    }
    
    func testFileItemCreation() {
        let item = FileItem(
            id: UUID(),
            kind: .document,
            name: "Test Document",
            pageCount: 5,
            contentKind: .pdf
        )
        
        XCTAssertEqual(item.name, "Test Document")
        XCTAssertEqual(item.pageCount, 5)
        XCTAssertTrue(item.isPDF)
    }
    
    func testEditOpCreation() {
        let op = EditOp.rotate90CW(pageIndex: 0)
        XCTAssertEqual(op.kind, .resize)
    }
    
    func testFileSystemError() {
        let error = FileSystemError.notFound(UUID())
        XCTAssertNotNil(error.errorDescription)
    }
    
    func testInkColor() {
        let black = InkColor.black
        XCTAssertEqual(black.hexString, "#000000")
    }
}