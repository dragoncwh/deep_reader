//
//  DesignSystem.swift
//  DeepReader
//
//  App design tokens and components
//

import SwiftUI

// MARK: - Colors
extension Color {
    static let appBackground = Color("Background", bundle: nil)
    static let appPrimary = Color("Primary", bundle: nil)
    static let appSecondary = Color("Secondary", bundle: nil)
    
    // Fallback colors if assets not set up
    static let readerBackground = Color(uiColor: .systemBackground)
    static let readerText = Color(uiColor: .label)
    static let readerAccent = Color.blue
}

// MARK: - Typography
struct AppTypography {
    static let title = Font.system(.title, design: .serif).weight(.semibold)
    static let headline = Font.system(.headline, design: .default).weight(.semibold)
    static let body = Font.system(.body, design: .default)
    static let caption = Font.system(.caption, design: .default)
    static let mono = Font.system(.body, design: .monospaced)
}

// MARK: - Spacing
struct Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
}

// MARK: - Corner Radius
struct CornerRadius {
    static let small: CGFloat = 4
    static let medium: CGFloat = 8
    static let large: CGFloat = 12
    static let full: CGFloat = 9999
}

// MARK: - Shadows
struct AppShadow {
    static let small = Shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    static let medium = Shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
    static let large = Shadow(color: .black.opacity(0.2), radius: 16, x: 0, y: 8)
}

struct Shadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

extension View {
    func appShadow(_ shadow: Shadow) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
}

// MARK: - Button Styles
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .background(Color.readerAccent)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Color.readerAccent)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .background(Color.readerAccent.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}

// MARK: - Card Style
struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
            .appShadow(AppShadow.small)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardModifier())
    }
}

// MARK: - Loading Indicator
struct LoadingView: View {
    var message: String = "Loading..."
    
    var body: some View {
        VStack(spacing: Spacing.md) {
            ProgressView()
                .scaleEffect(1.2)
            Text(message)
                .font(AppTypography.caption)
                .foregroundStyle(.secondary)
        }
        .padding(Spacing.lg)
        .cardStyle()
    }
}

// MARK: - Preview
#Preview("Design System") {
    VStack(spacing: Spacing.lg) {
        Text("Typography")
            .font(AppTypography.title)
        
        Text("Headline Style")
            .font(AppTypography.headline)
        
        Text("Body text goes here")
            .font(AppTypography.body)
        
        Button("Primary Button") {}
            .buttonStyle(.primary)
        
        Button("Secondary Button") {}
            .buttonStyle(.secondary)
        
        LoadingView()
    }
    .padding()
}
