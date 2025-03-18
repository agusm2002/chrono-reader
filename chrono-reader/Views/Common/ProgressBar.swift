// ProgressBar.swift

import SwiftUI

struct ProgressBar: View {
    var value: Double
    var height: CGFloat = 4
    var color: Color = .blue
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .frame(width: geometry.size.width)
                    .opacity(0.3)
                    .foregroundColor(.gray)

                Rectangle()
                    .frame(width: min(CGFloat(value) * geometry.size.width, geometry.size.width))
                    .foregroundColor(color)
                    .opacity(1.0)
                    .animation(.linear(duration: 0.3), value: value)
            }
        }
        .frame(height: height)
        .cornerRadius(height/2)
        .id(value)
    }
} 