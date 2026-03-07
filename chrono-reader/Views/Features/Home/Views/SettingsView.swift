import SwiftUI

struct SettingsView: View {
    @AppStorage("colorScheme") private var colorScheme: Int = 0 // 0: sistema, 1: claro, 2: oscuro
    @State private var forceUpdate: Bool = false // Para forzar actualización de la vista
    @StateObject private var homeViewModel = HomeViewModel()
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("OPCIONES").textCase(.uppercase)) {
                    NavigationLink(destination: AppearanceSettingsView()) {
                        HStack {
                            Image(systemName: "circle.lefthalf.filled")
                                .frame(width: 24, height: 24)
                                .foregroundColor(.gray)
                            
                            Text("Apariencia")
                            
                            Spacer()
                            
                            Text(colorSchemeText)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    NavigationLink(destination: LibrarySettingsView(viewModel: homeViewModel)) {
                        HStack {
                            Image(systemName: "books.vertical")
                                .frame(width: 24, height: 24)
                                .foregroundColor(.gray)
                            
                            Text("Biblioteca")
                            
                            Spacer()
                        }
                    }
                    
                    HStack {
                        Image(systemName: "trash")
                            .frame(width: 24, height: 24)
                            .foregroundColor(.gray)
                        
                        Text("Limpiar caché")
                        
                        Spacer()
                    }
                }
                
                // Secciones adicionales para tener suficiente contenido para scrollear
                Section(header: Text("ADICIONAL").textCase(.uppercase)) {
                    ForEach(1...5, id: \.self) { i in
                        HStack {
                            Image(systemName: "circle.fill")
                                .frame(width: 24, height: 24)
                                .foregroundColor(.gray)
                            
                            Text("Opción \(i)")
                            
                            Spacer()
                        }
                    }
                }
                
                Section(header: Text("INFORMACIÓN").textCase(.uppercase)) {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .frame(width: 24, height: 24)
                            .foregroundColor(.gray)
                        
                        Text("Versión")
                        
                        Spacer()
                        
                        Text("1.0.0")
                            .foregroundColor(.gray)
                    }
                    
                    HStack {
                        Image(systemName: "cpu")
                            .frame(width: 24, height: 24)
                            .foregroundColor(.gray)
                        
                        Text("Build")
                        
                        Spacer()
                        
                        Text("Debug")
                            .foregroundColor(.gray)
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Ajustes")
            .navigationBarTitleDisplayMode(.large)
        }
        .accentColor(Color.appTheme()) // Aplicar color del tema
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
    
    private var colorSchemeText: String {
        switch colorScheme {
        case 0: return "Sistema"
        case 1: return "Claro"
        case 2: return "Oscuro"
        default: return "Sistema"
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
