// ProgressBar.swift

import SwiftUI

struct ProgressBar: View {
    var value: Double
    var height: CGFloat = 4
    var color: Color = .blue
    
    // Identificador único para forzar la actualización
    private let id = UUID()

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .frame(width: geometry.size.width)
                    .opacity(0.15)
                    .foregroundColor(.primary)

                Rectangle()
                    .frame(width: min(CGFloat(value) * geometry.size.width, geometry.size.width))
                    .foregroundColor(color)
                    .animation(.easeInOut, value: value)
            }
        }
        .frame(height: height)
        .cornerRadius(height/2)
        .id("\(id)-\(value)")
    }
} 