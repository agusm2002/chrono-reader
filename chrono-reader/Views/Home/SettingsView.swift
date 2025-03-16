import SwiftUI

struct SettingsView: View {
    // Settings state
    @State private var darkModeEnabled = false
    @State private var notificationsEnabled = true
    @State private var fontSizeIndex = 1
    @State private var syncEnabled = true
    
    // Font size options
    let fontSizeOptions = ["Pequeña", "Media", "Grande"]
    
    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                // Transparent spacer to push content below the fixed header
                Color.clear.frame(height: 80)
                
                VStack(spacing: 24) {
                    // General Settings Section
                    VStack(alignment: .leading, spacing: 0) {
                        Text("General")
                            .font(.system(size: 18, weight: .bold))
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                        
                        VStack(spacing: 0) {
                            // Dark Mode Toggle
                            HStack {
                                Image(systemName: "moon.fill")
                                    .frame(width: 24, height: 24)
                                    .foregroundColor(.purple)
                                
                                Text("Modo oscuro")
                                    .font(.system(size: 16))
                                
                                Spacer()
                                
                                Toggle("", isOn: $darkModeEnabled)
                                    .labelsHidden()
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 24)
                            
                            Divider()
                                .padding(.leading, 24)
                            
                            // Font Size Picker
                            HStack {
                                Image(systemName: "textformat.size")
                                    .frame(width: 24, height: 24)
                                    .foregroundColor(.blue)
                                
                                Text("Tamaño de fuente")
                                    .font(.system(size: 16))
                                
                                Spacer()
                                
                                Picker("", selection: $fontSizeIndex) {
                                    ForEach(0..<fontSizeOptions.count, id: \.self) { index in
                                        Text(fontSizeOptions[index])
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 24)
                        }
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                        .padding(.horizontal, 24)
                    }
                    
                    // Notifications Section
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Notificaciones")
                            .font(.system(size: 18, weight: .bold))
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                        
                        VStack(spacing: 0) {
                            // Notifications Toggle
                            HStack {
                                Image(systemName: "bell.fill")
                                    .frame(width: 24, height: 24)
                                    .foregroundColor(.orange)
                                
                                Text("Notificaciones de lectura")
                                    .font(.system(size: 16))
                                
                                Spacer()
                                
                                Toggle("", isOn: $notificationsEnabled)
                                    .labelsHidden()
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 24)
                        }
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                        .padding(.horizontal, 24)
                    }
                    
                    // Cloud Sync Section
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Sincronización")
                            .font(.system(size: 18, weight: .bold))
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                        
                        VStack(spacing: 0) {
                            // Sync Toggle
                            HStack {
                                Image(systemName: "icloud.fill")
                                    .frame(width: 24, height: 24)
                                    .foregroundColor(.blue)
                                
                                Text("Sincronizar entre dispositivos")
                                    .font(.system(size: 16))
                                
                                Spacer()
                                
                                Toggle("", isOn: $syncEnabled)
                                    .labelsHidden()
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 24)
                        }
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                        .padding(.horizontal, 24)
                    }
                    
                    // About Section
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Acerca de")
                            .font(.system(size: 18, weight: .bold))
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                        
                        VStack(spacing: 0) {
                            // Version Info
                            HStack {
                                Image(systemName: "info.circle.fill")
                                    .frame(width: 24, height: 24)
                                    .foregroundColor(.gray)
                                
                                Text("Versión")
                                    .font(.system(size: 16))
                                
                                Spacer()
                                
                                Text("Build-state")
                                    .foregroundColor(.gray)
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 24)
                            
                            Divider()
                                .padding(.leading, 24)
                            
                            // Support Button
                            Button(action: {
                                // Action for tapping on support
                            }) {
                                HStack {
                                    Image(systemName: "questionmark.circle.fill")
                                        .frame(width: 24, height: 24)
                                        .foregroundColor(.green)
                                    
                                    Text("Soporte")
                                        .font(.system(size: 16))
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                            }
                            .foregroundColor(.primary)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 24)
                        }
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                        .padding(.horizontal, 24)
                    }
                    
                    Spacer(minLength: 100) // Aumentado de 90 a 100 para la barra de navegación más alta
                }
                .padding(.vertical, 20)
            }
            
            // New simplified header (like in HomeView)
            VStack(alignment: .leading, spacing: 8) {
                // Settings title
                Text("Ajustes")
                    .font(.system(size: 20, weight: .bold))
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
            }
            .background(Color.white)
            .frame(height: 80)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
