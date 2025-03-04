//MainTabView.swift

import SwiftUI
import UniformTypeIdentifiers

enum Tab {
    case home
    case settings
}

struct MainTabView: View {
    @State private var selectedTab: Tab = .home

    var body: some View {
        ZStack(alignment: .bottom) {
            // Content
            VStack(spacing: 0) {
                switch selectedTab {
                case .home:
                    HomeView()
                case .settings:
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity) // Asegura que el contenido llene la pantalla

            // Custom Tab Bar
            CustomTabBar(selectedTab: $selectedTab) // Usamos el nuevo CustomTabBar
                .ignoresSafeArea(.all)
        }
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
    }
}
