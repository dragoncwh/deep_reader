//
//  HighlightListView.swift
//  DeepReader
//
//  List view displaying all highlights for the current book
//

import SwiftUI

/// View displaying all highlights for a book, grouped by page
struct HighlightListView: View {
    @ObservedObject var viewModel: ReaderViewModel
    let onNavigateToHighlight: (Highlight) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var highlightToDelete: Highlight?
    @State private var showDeleteConfirmation = false
    @State private var highlightToEdit: Highlight?
    @State private var showNoteEditor = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.highlights.isEmpty {
                    emptyStateView
                } else {
                    highlightsList
                }
            }
            .navigationTitle("Highlights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Delete Highlight?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {
                    highlightToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let highlight = highlightToDelete {
                        deleteHighlight(highlight)
                    }
                }
            } message: {
                Text("This action cannot be undone.")
            }
            .sheet(isPresented: $showNoteEditor) {
                if let highlight = highlightToEdit {
                    NoteEditorView(
                        highlight: highlight,
                        onSave: { updatedNote in
                            updateHighlightNote(highlight, note: updatedNote)
                        }
                    )
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        ContentUnavailableView(
            "No Highlights",
            systemImage: "highlighter",
            description: Text("Select text in the document and choose a color to create highlights.")
        )
    }

    // MARK: - Highlights List

    private var highlightsList: some View {
        List {
            ForEach(sortedPageNumbers, id: \.self) { pageNumber in
                Section {
                    ForEach(highlightsForPage(pageNumber)) { highlight in
                        HighlightRowView(
                            highlight: highlight,
                            onTap: {
                                navigateToHighlight(highlight)
                            },
                            onEditNote: {
                                highlightToEdit = highlight
                                showNoteEditor = true
                            }
                        )
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                highlightToDelete = highlight
                                showDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }

                            Button {
                                highlightToEdit = highlight
                                showNoteEditor = true
                            } label: {
                                Label("Note", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                    }
                } header: {
                    Text("Page \(pageNumber + 1)")
                        .font(.headline)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Computed Properties

    private var sortedPageNumbers: [Int] {
        viewModel.highlightsByPage.keys.sorted()
    }

    private func highlightsForPage(_ page: Int) -> [Highlight] {
        viewModel.highlightsByPage[page] ?? []
    }

    // MARK: - Actions

    private func navigateToHighlight(_ highlight: Highlight) {
        dismiss()
        // Small delay to allow sheet to dismiss before navigation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onNavigateToHighlight(highlight)
        }
    }

    private func deleteHighlight(_ highlight: Highlight) {
        Task {
            await viewModel.deleteHighlight(highlight)
        }
        highlightToDelete = nil
    }

    private func updateHighlightNote(_ highlight: Highlight, note: String) {
        var updated = highlight
        updated.note = note.isEmpty ? nil : note
        Task {
            await viewModel.updateHighlight(updated)
        }
    }
}

// MARK: - Highlight Row View

private struct HighlightRowView: View {
    let highlight: Highlight
    let onTap: () -> Void
    let onEditNote: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: Spacing.sm) {
                // Color indicator
                RoundedRectangle(cornerRadius: 2)
                    .fill(highlight.color.color)
                    .frame(width: 4)
                    .frame(maxHeight: .infinity)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    // Highlighted text (truncated)
                    Text(highlight.text)
                        .font(AppTypography.body)
                        .lineLimit(2)
                        .foregroundStyle(.primary)

                    // Note preview if exists
                    if let note = highlight.note, !note.isEmpty {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "note.text")
                                .font(.caption2)
                            Text(note)
                                .lineLimit(1)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    // Timestamp
                    Text(highlight.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                // Navigate indicator
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, Spacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    HighlightListView(
        viewModel: {
            let vm = ReaderViewModel(book: Book(
                id: 1,
                title: "Sample Book",
                author: "Author",
                filePath: "/path/to/book.pdf",
                fileSize: 1024,
                pageCount: 100,
                addedAt: Date(),
                lastOpenedAt: nil,
                lastReadPage: 0,
                coverImagePath: nil
            ))
            return vm
        }(),
        onNavigateToHighlight: { _ in }
    )
}
