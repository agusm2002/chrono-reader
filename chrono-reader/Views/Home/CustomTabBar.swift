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
                .frame(width: 26, height: 26) // Aumenté el tamaño de los iconos
                .foregroundColor(selectedTab == tab ? .purple : .gray)
            Text(text)
                .font(.system(size: 12)) // Aumenté el tamaño del texto
                .foregroundColor(selectedTab == tab ? .purple : .gray)
        }
        .frame(height: 44)
        .onTapGesture {
            selectedTab = tab
        }
    }
}
