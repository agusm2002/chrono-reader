//CustomTabBar.swift

import SwiftUI

struct CustomTabBar: View {
    @Binding var selectedTab: Tab

    var body: some View {
        VStack(spacing: 0) {
            // Línea separadora
            Divider()
                .background(Color.gray.opacity(0.3))
            
            // Contenido de la barra
            HStack {
                Spacer()
                // Home Tab Button
                TabBarButton(tab: .home, selectedTab: $selectedTab, imageName: "house.fill", text: "Inicio")
                Spacer()
                // Settings Tab Button
                TabBarButton(tab: .settings, selectedTab: $selectedTab, imageName: "gear", text: "Ajustes")
                Spacer()
            }
            .padding(.top, 6)
            .padding(.bottom, 30)
        }
        .background(
            Material.ultraThinMaterial
        )
        .frame(height: 85)
    }
}

struct TabBarButton: View {
    let tab: Tab
    @Binding var selectedTab: Tab
    let imageName: String
    let text: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 26, height: 26)
                .foregroundColor(selectedTab == tab ? .blue : .gray)
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(selectedTab == tab ? .blue : .gray)
        }
        .frame(height: 42)
        .onTapGesture {
            selectedTab = tab
        }
    }
}
