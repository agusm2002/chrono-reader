// CustomViews.swift

import SwiftUI

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
            .foregroundColor(Color.blue)
    }
}

struct BlurredHeader: View {
    var body: some View {
        // Usar solo el material translúcido sin el gradiente de fondo
        Rectangle()
            .fill(Material.ultraThinMaterial)
    }
}
