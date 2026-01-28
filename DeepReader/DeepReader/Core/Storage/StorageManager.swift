//
//  StorageManager.swift
//  DeepReader
//
//  Centralized storage path management
//

import Foundation

/// Centralized storage path management
enum StorageManager {
    /// App storage directories
    enum Directory {
        case books
        case covers

        var url: URL {
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            switch self {
            case .books:
                return documentsURL.appendingPathComponent("Books", isDirectory: true)
            case .covers:
                return documentsURL.appendingPathComponent("Covers", isDirectory: true)
            }
        }
    }

    /// Get URL for a file in a directory
    static func url(for directory: Directory, fileName: String) -> URL {
        directory.url.appendingPathComponent(fileName)
    }

    /// Get path string for a file in a directory
    static func path(for directory: Directory, fileName: String) -> String {
        url(for: directory, fileName: fileName).path
    }

    /// Ensure a directory exists, creating if necessary
    static func ensureDirectoryExists(_ directory: Directory) throws {
        try FileManager.default.createDirectory(
            at: directory.url,
            withIntermediateDirectories: true
        )
    }
}
