//
//  DeepReaderApp.swift
//  DeepReader
//
//  A learning-first PDF reader app
//

import SwiftUI
import Combine

@main
struct DeepReaderApp: App {
    
    // MARK: - State Objects
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}

// MARK: - App State
/// Global application state shared across views
@MainActor
final class AppState: ObservableObject {
    @Published var selectedBook: Book?
    @Published var isShowingImporter = false
    /// Initial page to navigate to when opening a book (e.g., from search results)
    @Published var initialPage: Int?

    init() {
        // Initialize database and services
        setupServices()
    }

    private func setupServices() {
        do {
            try DatabaseService.shared.setup()
        } catch {
            print("Failed to initialize database: \(error.localizedDescription)")
        }
    }
}
