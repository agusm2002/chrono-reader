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
    @State private var forceUpdate: Bool = false
    @State private var searchText: String = ""
    @State private var isSearching: Bool = false
    @State private var keyboardHeight: CGFloat = 0
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack(alignment: .bottom) {
            // Content
            VStack(spacing: 0) {
                switch selectedTab {
                case .home:
                    HomeView(externalSearchText: $searchText, externalIsSearching: $isSearching)
                        .accentColor(Color.appTheme())
                case .collections:
                    CollectionsView(externalSearchText: $searchText, externalIsSearching: $isSearching)
                        .accentColor(Color.appTheme())
                case .settings:
                    SettingsView()
                        .accentColor(Color.appTheme())
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .id(forceUpdate)

            // Custom Tab Bar siempre visible, pero sin burbuja de búsqueda en Settings
            CustomTabBar(
                selectedTab: $selectedTab,
                searchText: $searchText,
                isSearching: $isSearching,
                showSearchBubble: selectedTab != .settings
            )
            .offset(y: keyboardHeight > 0 ? -(keyboardHeight - 20) : 0)
            .animation(.spring(response: 0.45, dampingFraction: 0.85), value: keyboardHeight)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .background(Color(.systemBackground))
        .ignoresSafeArea(.keyboard, edges: .bottom)
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
            
            // Observar teclado
            NotificationCenter.default.addObserver(
                forName: UIResponder.keyboardWillShowNotification,
                object: nil,
                queue: .main
            ) { notification in
                if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                    keyboardHeight = keyboardFrame.height
                }
            }
            
            NotificationCenter.default.addObserver(
                forName: UIResponder.keyboardWillHideNotification,
                object: nil,
                queue: .main
            ) { _ in
                keyboardHeight = 0
            }
        }
        // Optimizar actualizaciones de colorScheme para reducir mensajes en consola
        .onChange(of: colorScheme) { _ in
            // Almacenar el último valor para evitar actualizaciones innecesarias
            let isDark = colorScheme == .dark
            let currentScheme: ColorScheme = isDark ? .dark : .light
            
            if currentScheme != UserDefaults.standard.colorScheme {
                UserDefaults.standard.colorScheme = currentScheme
                withAnimation {
                    forceUpdate.toggle() // Forzar actualización cuando cambia el colorScheme
                }
            }
        }
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
    }
}

// Extensión para almacenar el último valor de colorScheme
extension UserDefaults {
    var colorScheme: ColorScheme {
        get {
            return bool(forKey: "lastColorSchemeWasDark") ? .dark : .light
        }
        set {
            set(newValue == .dark, forKey: "lastColorSchemeWasDark")
        }
    }
}
