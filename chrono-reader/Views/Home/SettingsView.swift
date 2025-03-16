import SwiftUI

struct SettingsView: View {
    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                // Transparent spacer to push content below the fixed header
                Color.clear.frame(height: 80)
                
                VStack(spacing: 24) {
                    // About Section - Solo mantenemos esta sección
                    VStack(alignment: .leading, spacing: 0) {
                        VStack(spacing: 0) {
                            // Version Info - Solo mantenemos esta información
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
                        }
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                        .padding(.horizontal, 24)
                    }
                    
                    Spacer(minLength: 100)
                }
                .padding(.vertical, 20)
            }
            
            // Header simplificado
            VStack(alignment: .leading, spacing: 8) {
                // Settings title
                Text("Ajustes")
                    .font(.system(size: 32, weight: .bold))
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
            }
            .background(Material.ultraThinMaterial)
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
