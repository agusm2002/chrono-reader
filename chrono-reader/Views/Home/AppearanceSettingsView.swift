import SwiftUI

struct AppearanceSettingsView: View {
    @AppStorage("colorScheme") private var colorScheme: Int = 0 // 0: sistema, 1: claro, 2: oscuro
    @AppStorage("appThemeColor") private var themeColorIndex: Int = 0 // 0: azul (por defecto)
    
    var body: some View {
        List {
            Section(header: Text("TEMA").textCase(.uppercase)) {
                Button {
                    colorScheme = 0
                } label: {
                    HStack {
                        Text("Sistema")
                        Spacer()
                        if colorScheme == 0 {
                            Image(systemName: "checkmark")
                                .foregroundColor(Color.appTheme())
                        }
                    }
                }
                .foregroundColor(.primary)
                
                Button {
                    colorScheme = 1
                } label: {
                    HStack {
                        Text("Claro")
                        Spacer()
                        if colorScheme == 1 {
                            Image(systemName: "checkmark")
                                .foregroundColor(Color.appTheme())
                        }
                    }
                }
                .foregroundColor(.primary)
                
                Button {
                    colorScheme = 2
                } label: {
                    HStack {
                        Text("Oscuro")
                        Spacer()
                        if colorScheme == 2 {
                            Image(systemName: "checkmark")
                                .foregroundColor(Color.appTheme())
                        }
                    }
                }
                .foregroundColor(.primary)
            }
            
            Section(header: Text("COLOR DEL TEMA").textCase(.uppercase)) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(0..<Color.themeColors.count, id: \.self) { index in
                            let color = Color.themeColors[index]
                            Button {
                                themeColorIndex = index
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(color)
                                        .frame(width: 50, height: 50)
                                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                                    
                                    if themeColorIndex == index {
                                        Circle()
                                            .stroke(Color.white, lineWidth: 2)
                                            .frame(width: 50, height: 50)
                                        
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)
                }
                
                Text("Color actual: \(Color.themeName[safe: themeColorIndex] ?? "Azul")")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.vertical, 8)
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("Apariencia")
        .navigationBarTitleDisplayMode(.large)
    }
}

struct AppearanceSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            AppearanceSettingsView()
        }
    }
} 