import SwiftUI

struct LibrarySettingsView: View {
    @ObservedObject var viewModel: HomeViewModel
    
    var body: some View {
        List {
            // Sección para configurar las secciones del Home
            Section(header: Text("SECCIONES DEL HOME").textCase(.uppercase)) {
                Toggle(isOn: $viewModel.showRecentSection) {
                    HStack {
                        Image(systemName: "clock")
                            .frame(width: 24, height: 24)
                            .foregroundColor(.gray)
                        
                        Text("Mostrar 'Continuar leyendo'")
                    }
                }
                
                Toggle(isOn: $viewModel.showCollectionsSection) {
                    HStack {
                        Image(systemName: "folder")
                            .frame(width: 24, height: 24)
                            .foregroundColor(.gray)
                        
                        Text("Mostrar 'Tus colecciones'")
                    }
                }
            }
            
            Section(header: Text("Biblioteca").textCase(.uppercase)) {
                Button(action: {
                    viewModel.verifyAndRepairBookPaths()
                }) {
                    HStack {
                        Image(systemName: "checkmark.circle")
                            .frame(width: 24, height: 24)
                            .foregroundColor(.gray)
                        
                        Text("Verificar y reparar archivos")
                        
                        Spacer()
                    }
                }
                
                Button(action: {
                    // Mostrar alerta de confirmación para reiniciar
                    let confirmAlert = UIAlertController(title: "Reiniciar biblioteca", message: "¿Estás seguro de que quieres borrar todos los libros y colecciones?", preferredStyle: .alert)
                    
                    confirmAlert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
                    confirmAlert.addAction(UIAlertAction(title: "Reiniciar", style: .destructive) { _ in
                        viewModel.resetToSampleBooks()
                    })
                    
                    // Presentar la alerta de confirmación
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let rootViewController = windowScene.windows.first?.rootViewController {
                        rootViewController.present(confirmAlert, animated: true)
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                            .frame(width: 24, height: 24)
                            .foregroundColor(.gray)
                        
                        Text("Reiniciar biblioteca")
                        
                        Spacer()
                    }
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("Biblioteca")
        .navigationBarTitleDisplayMode(.large)
    }
} 
