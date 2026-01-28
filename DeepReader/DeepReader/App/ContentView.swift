//
//  ContentView.swift
//  DeepReader
//
//  Main navigation container
//

import SwiftUI
import UniformTypeIdentifiers

extension Notification.Name {
    static let bookImported = Notification.Name("bookImported")
}

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var isImporting = false
    @State private var importError: String?
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            LibraryView()
                .navigationDestination(for: Book.self) { book in
                    ReaderView(book: book)
                }
        }
        .onChange(of: appState.selectedBook) { _, newBook in
            // Navigate to book when selectedBook is set (e.g., from search results)
            if let book = newBook {
                navigationPath.append(book)
                appState.selectedBook = nil
            }
        }
        .overlay {
            if isImporting {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Importing PDF...")
                            .font(.headline)
                    }
                    .padding(24)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
        }
        .fileImporter(
            isPresented: $appState.isShowingImporter,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: true
        ) { result in
            handleFileImport(result)
        }
        .alert("Import Failed", isPresented: .init(
            get: { importError != nil },
            set: { if !$0 { importError = nil } }
        )) {
            Button("OK") { importError = nil }
        } message: {
            Text(importError ?? "")
        }
    }
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            Task {
                isImporting = true
                defer { isImporting = false }
                for url in urls {
                    await importPDF(from: url)
                }
            }
        case .failure(let error):
            importError = error.localizedDescription
        }
    }

    private func importPDF(from url: URL) async {
        do {
            let book = try await BookService.shared.importPDF(from: url)
            print("Successfully imported: \(book.title)")
            NotificationCenter.default.post(name: .bookImported, object: nil)
        } catch {
            importError = error.localizedDescription
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
