//
//  MainTabView.swift
//  chrono-reader
//
//  Created by Agustin Monti on 02/03/2025.
//
import SwiftUI
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
            
            // Custom Tab Bar
            HStack {
                Spacer()
                
                // Home Tab Button
                VStack(spacing: 4) {
                    Image(systemName: "house.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                        .foregroundColor(selectedTab == .home ? .white : .white.opacity(0.7))
                    
                    Text("Inicio")
                        .font(.system(size: 10))
                        .foregroundColor(selectedTab == .home ? .white : .white.opacity(0.7))
                }
                .frame(height: 44)
                .onTapGesture {
                    selectedTab = .home
                }
                
                Spacer()
                
                // Settings Tab Button
                VStack(spacing: 4) {
                    Image(systemName: "gear")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                        .foregroundColor(selectedTab == .settings ? .white : .white.opacity(0.7))
                    
                    Text("Ajustes")
                        .font(.system(size: 10))
                        .foregroundColor(selectedTab == .settings ? .white : .white.opacity(0.7))
                }
                .frame(height: 44)
                .onTapGesture {
                    selectedTab = .settings
                }
                
                Spacer()
            }
            .padding(.bottom, 4)
            .background(BlurredTabBar())
        }
        .ignoresSafeArea(edges: .bottom)  // This ensures the tab bar extends to the bottom
    }
}
struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
    }
}
