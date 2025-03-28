//CustomTabBar.swift

import SwiftUI

struct CustomTabBar: View {
    @Binding var selectedTab: Tab
    @State private var forceUpdate: Bool = false // Para forzar actualización de la vista
    @Environment(\.colorScheme) var colorScheme // Añadir environment para detectar cambios de colorScheme

    var body: some View {
        HStack {
            Spacer()
            TabBarButton(tab: .home, selectedTab: $selectedTab, imageName: "house.fill", text: "Inicio")
            Spacer()
            TabBarButton(tab: .collections, selectedTab: $selectedTab, imageName: "books.vertical.fill", text: "Colecciones")
            Spacer()
            TabBarButton(tab: .settings, selectedTab: $selectedTab, imageName: "gear", text: "Ajustes")
            Spacer()
        }
        .padding(.vertical, 8)
        .frame(height: 49)
        .id(forceUpdate) // Forzar actualización cuando cambia el tema
        .onAppear {
            // Observar cambios de tema
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("ThemeDidChange"),
                object: nil,
                queue: .main
            ) { _ in
                withAnimation {
                    forceUpdate.toggle() // Forzar actualización de la vista
                }
            }
        }
        .onChange(of: colorScheme) { _ in
            withAnimation {
                forceUpdate.toggle() // Forzar actualización cuando cambia el colorScheme
            }
        }
    }
}

struct TabBarButton: View {
    let tab: Tab
    @Binding var selectedTab: Tab
    let imageName: String
    let text: String
    @State private var forceUpdate: Bool = false // Para forzar actualización de la vista

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 26, height: 26)
                .foregroundColor(selectedTab == tab ? Color.appTheme() : .gray)
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(selectedTab == tab ? Color.appTheme() : .gray)
        }
        .frame(height: 42)
        .onTapGesture {
            selectedTab = tab
        }
        .id(forceUpdate) // Forzar actualización cuando cambia el tema
        .onAppear {
            // Observar cambios de tema
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("ThemeDidChange"),
                object: nil,
                queue: .main
            ) { _ in
                withAnimation {
                    forceUpdate.toggle() // Forzar actualización de la vista
                }
            }
        }
    }
}
