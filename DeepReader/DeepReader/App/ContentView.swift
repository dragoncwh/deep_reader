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

    var body: some View {
        NavigationStack {
            LibraryView()
                .navigationDestination(for: Book.self) { book in
                    ReaderView(book: book)
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
