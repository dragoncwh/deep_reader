//
//  ServiceErrorTests.swift
//  DeepReaderTests
//
//  Unit tests for service error types
//

import XCTest
@testable import DeepReader

final class ServiceErrorTests: XCTestCase {

    // MARK: - DatabaseServiceError Tests

    func testDatabaseServiceError_notInitialized_hasDescription() {
        let error = DatabaseServiceError.notInitialized

        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription!.isEmpty)
        XCTAssertTrue(error.errorDescription!.lowercased().contains("database") ||
                     error.errorDescription!.lowercased().contains("initialized"))
    }

    // MARK: - BookServiceError Tests

    func testBookServiceError_accessDenied_hasDescription() {
        let error = BookServiceError.accessDenied

        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription!.isEmpty)
    }

    func testBookServiceError_invalidPDF_hasDescription() {
        let error = BookServiceError.invalidPDF

        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription!.isEmpty)
        XCTAssertTrue(error.errorDescription!.lowercased().contains("pdf") ||
                     error.errorDescription!.lowercased().contains("valid"))
    }

    func testBookServiceError_importFailed_hasDescription() {
        let error = BookServiceError.importFailed

        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription!.isEmpty)
        XCTAssertTrue(error.errorDescription!.lowercased().contains("import") ||
                     error.errorDescription!.lowercased().contains("fail"))
    }

    // MARK: - PDFServiceError Tests

    func testPDFServiceError_imageRenderingFailed_hasDescription() {
        let error = PDFServiceError.imageRenderingFailed

        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription!.isEmpty)
    }

    func testPDFServiceError_coverSaveFailed_hasDescription() {
        let error = PDFServiceError.coverSaveFailed

        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription!.isEmpty)
        XCTAssertTrue(error.errorDescription!.lowercased().contains("cover") ||
                     error.errorDescription!.lowercased().contains("save"))
    }

    func testPDFServiceError_ocrFailed_hasDescription() {
        let error = PDFServiceError.ocrFailed

        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription!.isEmpty)
        XCTAssertTrue(error.errorDescription!.lowercased().contains("ocr"))
    }

    // MARK: - Error Conformance Tests

    func testDatabaseServiceError_conformsToLocalizedError() {
        let error: LocalizedError = DatabaseServiceError.notInitialized
        XCTAssertNotNil(error.errorDescription)
    }

    func testBookServiceError_conformsToLocalizedError() {
        let errors: [LocalizedError] = [
            BookServiceError.accessDenied,
            BookServiceError.invalidPDF,
            BookServiceError.importFailed
        ]

        for error in errors {
            XCTAssertNotNil(error.errorDescription)
        }
    }

    func testPDFServiceError_conformsToLocalizedError() {
        let errors: [LocalizedError] = [
            PDFServiceError.imageRenderingFailed,
            PDFServiceError.coverSaveFailed,
            PDFServiceError.ocrFailed
        ]

        for error in errors {
            XCTAssertNotNil(error.errorDescription)
        }
    }
}
