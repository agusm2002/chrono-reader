//MainTabView.swift

import SwiftUI
import UniformTypeIdentifiers

enum Tab {
    case home
    case collections
    case settings
}

struct MainTabView: View {
    @State private var selectedTab: Tab = .home
    @State private var forceUpdate: Bool = false // Para forzar actualización de la vista
    @Environment(\.colorScheme) var colorScheme // Añadir environment para detectar cambios de colorScheme

    var body: some View {
        ZStack(alignment: .bottom) {
            // Content
            VStack(spacing: 0) {
                switch selectedTab {
                case .home:
                    HomeView()
                        .accentColor(Color.appTheme()) // Aplicar color a los botones de navegación
                case .collections:
                    CollectionsView()
                        .accentColor(Color.appTheme()) // Aplicar color a los botones de navegación
                case .settings:
                    SettingsView()
                        .accentColor(Color.appTheme()) // Aplicar color a los botones de navegación
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity) // Asegura que el contenido llene la pantalla
            .id(forceUpdate) // Forzar actualización cuando cambia el tema

            // Custom Tab Bar
            VStack(spacing: 0) {
                Divider()
                CustomTabBar(selectedTab: $selectedTab)
            }
            .background(.ultraThinMaterial)
        }
        .background(Color(.systemBackground))
        .ignoresSafeArea(.keyboard)
        .accentColor(Color.appTheme()) // Aplicar color a nivel global
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

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
    }
}
