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

    var body: some View {
        ZStack(alignment: .bottom) {
            // Content
            VStack(spacing: 0) {
                switch selectedTab {
                case .home:
                    HomeView()
                case .collections:
                    CollectionsView()
                case .settings:
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity) // Asegura que el contenido llene la pantalla

            // Custom Tab Bar
            CustomTabBar(selectedTab: $selectedTab)
                .padding(.bottom, 0)
        }
        .background(Color(.systemBackground))
        .edgesIgnoringSafeArea(.bottom) // Ignorar el safe area inferior para que la barra esté en el borde
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
    }
}
