//
//  CustomTabBar.swift
//  chrono-reader
//
//  Created by Agustin Monti on 03/03/2025.
//

import SwiftUI

struct CustomTabBar: View {
    @Binding var selectedTab: Tab

    var body: some View {
        HStack {
            Spacer()

            // Home Tab Button
            TabBarButton(tab: .home, selectedTab: $selectedTab, imageName: "house.fill", text: "Inicio")

            Spacer()

            // Settings Tab Button
            TabBarButton(tab: .settings, selectedTab: $selectedTab, imageName: "gear", text: "Ajustes")

            Spacer()
        }
        .padding(.bottom, 4)
        .frame(height: 60) // Ajusta la altura según sea necesario
        .background(
            Material.ultraThinMaterial
        )
    }
}

struct TabBarButton: View {
    let tab: Tab
    @Binding var selectedTab: Tab
    let imageName: String
    let text: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)
                .foregroundColor(selectedTab == tab ? .blue : .gray) // Cambié los colores para mejor contraste

            Text(text)
                .font(.system(size: 10))
                .foregroundColor(selectedTab == tab ? .blue : .gray) // Cambié los colores para mejor contraste
        }
        .frame(height: 44)
        .onTapGesture {
            selectedTab = tab
        }
    }
}
