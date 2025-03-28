// CustomViews.swift

import SwiftUI

// Extension para colores del tema
extension Color {
    static var themeColors: [Color] = [
        .blue,
        .red,
        .green,
        .purple,
        .orange,
        .pink,
        .teal
    ]
    
    static var themeName: [String] = [
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
        return themeColors[safe: colorIndex] ?? .blue
    }
}

// Extensión para acceso seguro a arrays
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
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
        Text(text)
            .font(.system(size: fontSize, weight: .bold))
            .foregroundColor(Color.appTheme())
    }
}

struct BlurredHeader: View {
    var body: some View {
        // Usar solo el material translúcido sin el gradiente de fondo
        Rectangle()
            .fill(Material.ultraThinMaterial)
    }
}
