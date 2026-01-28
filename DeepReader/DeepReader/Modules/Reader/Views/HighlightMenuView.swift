//
//  HighlightMenuView.swift
//  DeepReader
//
//  Floating menu for highlight color selection
//

import SwiftUI

/// Floating menu that appears when text is selected, allowing the user to choose a highlight color
struct HighlightMenuView: View {
    let position: CGPoint
    let onColorSelected: (HighlightColor) -> Void
    let onDismiss: () -> Void

    @State private var isVisible = false

    var body: some View {
        GeometryReader { geometry in
            // Menu content only - no blocking overlay
            // Menu dismisses when PDF selection changes (user taps elsewhere)
            highlightMenu
                .position(menuPosition(in: geometry))
                .opacity(isVisible ? 1 : 0)
                .scaleEffect(isVisible ? 1 : 0.8)
        }
        .allowsHitTesting(true)
        .onAppear {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                isVisible = true
            }
        }
    }

    private var highlightMenu: some View {
        HStack(spacing: Spacing.sm) {
            ForEach(HighlightColor.allCases, id: \.self) { color in
                ColorButton(color: color) {
                    onColorSelected(color)
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        )
    }

    /// Calculate menu position, keeping it within screen bounds
    private func menuPosition(in geometry: GeometryProxy) -> CGPoint {
        let menuWidth: CGFloat = 220
        let menuHeight: CGFloat = 50
        let padding: CGFloat = 16

        // Start with the selection position
        var x = position.x
        var y = position.y - menuHeight - 10 // Position above selection

        // Keep menu within horizontal bounds
        let minX = padding + menuWidth / 2
        let maxX = geometry.size.width - padding - menuWidth / 2
        x = max(minX, min(maxX, x))

        // If menu would go above screen, position it below selection
        if y < padding + menuHeight / 2 {
            y = position.y + menuHeight + 10
        }

        // Keep menu within vertical bounds
        let minY = padding + menuHeight / 2
        let maxY = geometry.size.height - padding - menuHeight / 2
        y = max(minY, min(maxY, y))

        return CGPoint(x: x, y: y)
    }
}

/// Individual color button in the highlight menu
private struct ColorButton: View {
    let color: HighlightColor
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(displayColor)
                .frame(width: 32, height: 32)
                .overlay(
                    Circle()
                        .strokeBorder(Color.primary.opacity(0.2), lineWidth: 1)
                )
                .scaleEffect(isPressed ? 0.9 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = false
                    }
                }
        )
        .accessibilityLabel("\(color.rawValue) highlight")
    }

    /// Display color (full opacity for button display)
    private var displayColor: Color {
        switch color {
        case .yellow: return .yellow
        case .green: return .green
        case .blue: return .blue
        case .pink: return .pink
        case .purple: return .purple
        }
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.1)
            .ignoresSafeArea()

        HighlightMenuView(
            position: CGPoint(x: 200, y: 300),
            onColorSelected: { color in
                print("Selected: \(color)")
            },
            onDismiss: {
                print("Dismissed")
            }
        )
    }
}
