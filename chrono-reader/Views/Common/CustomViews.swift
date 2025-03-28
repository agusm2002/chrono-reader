// CustomViews.swift

import SwiftUI

// Extension para colores del tema
extension Color {
    static var themeColors: [Color] = [
        Color(red: 0.4, green: 0.5, blue: 0.9), // Legacy - Brighter indigo
        .blue,
        .red,
        .green,
        .purple,
        .orange,
        .pink,
        .teal
    ]
    
    static var themeName: [String] = [
        "Legacy",
        "Azul",
        "Rojo",
        "Verde",
        "Púrpura",
        "Naranja",
        "Rosa",
        "Turquesa"
    ]
    
    static func appTheme() -> Color {
        let colorIndex = UserDefaults.standard.integer(forKey: "appThemeColor")
        if colorIndex == 0 {
            // Legacy theme - return a gradient color
            return Color(red: 0.4, green: 0.5, blue: 0.9) // Brighter indigo component
        }
        return themeColors[safe: colorIndex] ?? .blue
    }
}

// Extensión para acceso seguro a arrays
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// View modifier para el tema Legacy
struct LegacyThemeModifier: ViewModifier {
    func body(content: Content) -> some View {
        let colorIndex = UserDefaults.standard.integer(forKey: "appThemeColor")
        if colorIndex == 0 {
            content
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.4, green: 0.5, blue: 0.9), // Brighter indigo
                            Color(red: 0.35, green: 0.25, blue: 0.6)  // Softer purple
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        } else {
            content
        }
    }
}

extension View {
    func legacyTheme() -> some View {
        modifier(LegacyThemeModifier())
    }
}

struct GradientBackground: View {
    var body: some View {
        Color(.systemBackground)
            .ignoresSafeArea()
    }
}

struct HeaderGradientText: View {
    let text: String
    let fontSize: CGFloat

    init(_ text: String, fontSize: CGFloat = 24) {
        self.text = text
        self.fontSize = fontSize
    }

    var body: some View {
        let colorIndex = UserDefaults.standard.integer(forKey: "appThemeColor")
        if colorIndex == 0 {
            // Legacy theme with gradient
            Text(text)
                .font(.system(size: fontSize, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.4, green: 0.5, blue: 0.9),
                            Color(red: 0.35, green: 0.25, blue: 0.6)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        } else {
            Text(text)
                .font(.system(size: fontSize, weight: .bold))
                .foregroundColor(Color.appTheme())
        }
    }
}

struct BlurredHeader: View {
    var body: some View {
        // Usar solo el material translúcido sin el gradiente de fondo
        Rectangle()
            .fill(Material.ultraThinMaterial)
    }
}

struct GradientButton: View {
    let text: String
    let action: () -> Void
    let icon: String?
    
    init(_ text: String, icon: String? = nil, action: @escaping () -> Void) {
        self.text = text
        self.icon = icon
        self.action = action
    }
    
    var body: some View {
        let colorIndex = UserDefaults.standard.integer(forKey: "appThemeColor")
        Button(action: action) {
            HStack(spacing: 10) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.headline)
                }
                Text(text)
                    .font(.headline)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                Group {
                    if colorIndex == 0 {
                        // Legacy theme with gradient
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.4, green: 0.5, blue: 0.9),
                                Color(red: 0.35, green: 0.25, blue: 0.6)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    } else {
                        Color.appTheme()
                    }
                }
            )
            .cornerRadius(10)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}
