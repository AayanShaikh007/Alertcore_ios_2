import SwiftUI

struct Theme {
    static let darkBg = LinearGradient(
        colors: [Color(red: 0.03, green: 0.03, blue: 0.06), Color(red: 0.06, green: 0.06, blue: 0.12)],
        startPoint: .top,
        endPoint: .bottom
    )
    
    static let cardBackground = Color(white: 0.12, opacity: 0.5)
    
    static let accentGreen = Color(red: 0.1, green: 0.9, blue: 0.6)      // Neon Green
    static let accentCoral = Color(red: 1.0, green: 0.35, blue: 0.35)    // Neon Coral
    static let inactiveGrey = Color(red: 0.45, green: 0.45, blue: 0.5)
    
    static let textPrimary = Color.white
    static let textSecondary = Color(white: 0.7)
}

struct GlassCardModifier: ViewModifier {
    var borderColor: Color = .white.opacity(0.15)
    var borderWidth: CGFloat = 1
    
    func body(content: Content) -> some View {
        content
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [borderColor, borderColor.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: borderWidth
                    )
            )
            .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
    }
}

extension View {
    func glassCardStyle(borderColor: Color = .white.opacity(0.15), borderWidth: CGFloat = 1) -> some View {
        modifier(GlassCardModifier(borderColor: borderColor, borderWidth: borderWidth))
    }
}
