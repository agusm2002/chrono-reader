//CustomTabBar.swift

import SwiftUI

struct CustomTabBar: View {
    @Binding var selectedTab: Tab
    @Binding var searchText: String
    @Binding var isSearching: Bool
    var showSearchBubble: Bool = true
    @Environment(\.colorScheme) var colorScheme
    @Namespace private var animation
    @FocusState private var isSearchFieldFocused: Bool

        private let tabs: [(tab: Tab, icon: String, label: String)] = [
            (.home, "house.fill", "Inicio"),
            (.collections, "books.vertical.fill", "Colecciones"),
            (.settings, "gear", "Ajustes")
        ]

    var body: some View {
        HStack(spacing: 12) {
            if !isSearching {
                // Tabs principales
                HStack(spacing: 8) {
                    ForEach(tabs, id: \.tab) { item in
                        TabBarButton(
                            tab: item.tab,
                            selectedTab: $selectedTab,
                            icon: item.icon,
                            label: item.label,
                            namespace: animation
                        )
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    ZStack {
                        // Base Material con efecto glass
                        Capsule()
                            .fill(Material.ultraThinMaterial)
                        
                        // Reflejo de vidrio líquido
                        Capsule()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(stops: [
                                        .init(color: Color.white.opacity(0.3), location: 0),
                                        .init(color: Color.white.opacity(0.1), location: 0.5),
                                        .init(color: Color.clear, location: 1)
                                    ]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .opacity(0.6)
                    }
                )
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
                .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
            if showSearchBubble {
                if isSearching {
                    // Barra de búsqueda expandida con botón cancelar separado
                    HStack(spacing: 10) {
                        // Botón de cancelar como burbuja separada (misma altura que la barra)
                        Button(action: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                isSearching = false
                                searchText = ""
                                isSearchFieldFocused = false
                            }
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.gray)
                                .frame(width: 44, height: 44)
                                .background(
                                    ZStack {
                                        Circle()
                                            .fill(Material.ultraThinMaterial)
                                        
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    gradient: Gradient(stops: [
                                                        .init(color: Color.white.opacity(0.3), location: 0),
                                                        .init(color: Color.white.opacity(0.1), location: 0.5),
                                                        .init(color: Color.clear, location: 1)
                                                    ]),
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                )
                                            )
                                            .opacity(0.6)
                                    }
                                )
                                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
                                .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
                        }
                        
                        // Barra de búsqueda
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.gray)

                            TextField("Buscar...", text: $searchText)
                                .font(.system(size: 16))
                                .focused($isSearchFieldFocused)

                            if !searchText.isEmpty {
                                Button(action: {
                                    searchText = ""
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 44) // Altura fija igual a la burbuja de cancelar
                        .background(
                            ZStack {
                                // Base Material con efecto glass
                                Capsule()
                                    .fill(Material.ultraThinMaterial)
                                
                                // Reflejo de vidrio líquido
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(stops: [
                                                .init(color: Color.white.opacity(0.3), location: 0),
                                                .init(color: Color.white.opacity(0.1), location: 0.5),
                                                .init(color: Color.clear, location: 1)
                                            ]),
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .opacity(0.6)
                            }
                        )
                        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
                        .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
                        .frame(maxWidth: .infinity)
                    }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                } else {
                    // Bubble de búsqueda
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                            isSearching = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                isSearchFieldFocused = true
                            }
                        }
                    }) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.gray)
                            .frame(width: 48, height: 48)
                            .background(
                                ZStack {
                                    // Base Material con efecto glass
                                    RoundedRectangle(cornerRadius: 24)
                                        .fill(Material.ultraThinMaterial)
                                    
                                    // Reflejo de vidrio líquido
                                    RoundedRectangle(cornerRadius: 24)
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(stops: [
                                                    .init(color: Color.white.opacity(0.3), location: 0),
                                                    .init(color: Color.white.opacity(0.1), location: 0.5),
                                                    .init(color: Color.clear, location: 1)
                                                ]),
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                        .opacity(0.6)
                                }
                            )
                            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
                            .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .padding(.horizontal, isSearching ? 8 : 40)
        .padding(.bottom, 2)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: isSearching)
        .onChange(of: isSearchFieldFocused) { focused in
            if !focused && searchText.isEmpty {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    isSearching = false
                }
            }
        }
    }
    }

// Botón individual de la tab bar
struct TabBarButton: View {
    let tab: Tab
    @Binding var selectedTab: Tab
    let icon: String
    let label: String
    var namespace: Namespace.ID

    private var isSelected: Bool {
        selectedTab == tab
    }

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = tab
            }
        }) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(isSelected ? Color.appTheme() : .gray)
                .frame(width: 60, height: 40)
                .background(
                    ZStack {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.appTheme().opacity(0.15))
                                .matchedGeometryEffect(id: "TAB", in: namespace)
                        }
                    }
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
