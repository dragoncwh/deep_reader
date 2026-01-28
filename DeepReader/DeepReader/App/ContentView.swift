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
    
    var body: some View {
        NavigationStack {
            LibraryView()
                .navigationDestination(for: Book.self) { book in
                    ReaderView(book: book)
                }
        }
        .fileImporter(
            isPresented: $appState.isShowingImporter,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: true
        ) { result in
            handleFileImport(result)
        }
    }
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            Task {
                for url in urls {
                    await importPDF(from: url)
                }
            }
        case .failure(let error):
            print("Import failed: \(error.localizedDescription)")
        }
    }
    
    private func importPDF(from url: URL) async {
        do {
            let book = try await BookService.shared.importPDF(from: url)
            print("Successfully imported: \(book.title)")
            NotificationCenter.default.post(name: .bookImported, object: nil)
        } catch {
            print("Import failed: \(error.localizedDescription)")
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
