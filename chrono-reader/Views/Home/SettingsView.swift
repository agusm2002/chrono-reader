import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationView {
            List {
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
                
                Section(header: Text("OPCIONES").textCase(.uppercase)) {
                    HStack {
                        Image(systemName: "text.format")
                            .frame(width: 24, height: 24)
                            .foregroundColor(.gray)
                        
                        Text("Apariencia")
                        
                        Spacer()
                        
                        Text("Sistema")
                            .foregroundColor(.gray)
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
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Ajustes")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
