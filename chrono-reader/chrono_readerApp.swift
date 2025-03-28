//
//  chrono_readerApp.swift
//  chrono-reader
//
//  Created by Agustin Monti on 02/03/2025.
//
// App/ChronoReaderApp.swift
// App/ChronoReaderApp.swift
import SwiftUI

// Añadir claves al Info.plist
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        print("Aplicación iniciada")
        
        // Configurar apariencia global de la navegación
        configureGlobalAppearance()
        
        return true
    }
    
    // Función para configurar la apariencia global de la aplicación
    private func configureGlobalAppearance() {
        // Observar los cambios en el color del tema
        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            // Verificar si el cambio afecta al color del tema
            if let userDefaults = notification.object as? UserDefaults,
               userDefaults.object(forKey: "appThemeColor") != nil {
                print("Cambio detectado en el color del tema")
                self?.updateNavigationBarAppearance()
            } else {
                // Para otros cambios de UserDefaults
                self?.updateNavigationBarAppearance()
            }
        }
        
        // Configurar apariencia inicial
        updateNavigationBarAppearance()
    }
    
    // Actualizar la apariencia de la barra de navegación
    private func updateNavigationBarAppearance() {
        let themeColor = Color.appTheme().toUIColor()
        
        // Configuración para iOS 13+
        UINavigationBar.appearance().tintColor = themeColor
        
        // Configuración mejorada para iOS 15+
        if #available(iOS 15.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithDefaultBackground()
            
            // Establecer colores de texto y botones
            appearance.titleTextAttributes = [.foregroundColor: UIColor.label]
            appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.label]
            
            // Configurar apariencia de botones
            let buttonAppearance = UIBarButtonItemAppearance(style: .plain)
            buttonAppearance.normal.titleTextAttributes = [.foregroundColor: themeColor]
            appearance.buttonAppearance = buttonAppearance
            
            // Configurar apariencia de botones "back"
            let backButtonAppearance = UIBarButtonItemAppearance(style: .plain)
            backButtonAppearance.normal.titleTextAttributes = [.foregroundColor: themeColor]
            appearance.backButtonAppearance = backButtonAppearance
            
            // Asegurarse de que la imagen del botón "back" tenga el color del tema
            UINavigationBar.appearance().standardAppearance = appearance
            UINavigationBar.appearance().scrollEdgeAppearance = appearance
            UINavigationBar.appearance().compactAppearance = appearance
            
            // Forzar actualización de todas las barras de navegación
            UIApplication.shared.windows.forEach { window in
                window.rootViewController?.navigationController?.navigationBar.tintColor = themeColor
            }
        }
        
        // Configurar tintColor global para todos los botones de barra
        UIBarButtonItem.appearance().tintColor = themeColor
        
        // Configurar tintColor global para controles como UISwitch, UISlider, etc.
        UIView.appearance(whenContainedInInstancesOf: [UISwitch.self]).tintColor = themeColor
        UISwitch.appearance().onTintColor = themeColor
        UISlider.appearance().tintColor = themeColor
        
        // Forzar actualización de todas las ventanas
        DispatchQueue.main.async {
            // Notificar el cambio de tema
            NotificationCenter.default.post(name: NSNotification.Name("ThemeDidChange"), object: nil)
            
            // Forzar actualización de las ventanas
            UIApplication.shared.windows.forEach { window in
                window.subviews.forEach { view in
                    view.setNeedsLayout()
                    view.layoutIfNeeded()
                }
                window.setNeedsLayout()
                window.layoutIfNeeded()
            }
        }
    }
}

// Extensión para convertir Color de SwiftUI a UIColor
extension Color {
    func toUIColor() -> UIColor {
        if #available(iOS 14.0, *) {
            return UIColor(self)
        } else {
            let scanner = Scanner(string: self.description.trimmingCharacters(in: CharacterSet.alphanumerics.inverted))
            var hexNumber: UInt64 = 0
            var r: CGFloat = 0.0, g: CGFloat = 0.0, b: CGFloat = 0.0, a: CGFloat = 0.0
            
            let result = scanner.scanHexInt64(&hexNumber)
            if result {
                r = CGFloat((hexNumber & 0xff000000) >> 24) / 255
                g = CGFloat((hexNumber & 0x00ff0000) >> 16) / 255
                b = CGFloat((hexNumber & 0x0000ff00) >> 8) / 255
                a = CGFloat(hexNumber & 0x000000ff) / 255
                return UIColor(red: r, green: g, blue: b, alpha: a)
            }
            return UIColor.blue // Color por defecto si falla la conversión
        }
    }
}

@main
struct ChronoReaderApp: App {
    // Registrar el AppDelegate
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // Observar el estado de carga global
    @StateObject private var loadingManager = LoadingManager.shared
    
    // Estado para las animaciones
    @State private var isAnimating = false
    @State private var scaleAmount = 1.0
    
    // Preferencia de esquema de color
    @AppStorage("colorScheme") private var colorScheme: Int = 0 // 0: sistema, 1: claro, 2: oscuro
    @AppStorage("appThemeColor") private var themeColorIndex: Int = 0 // Observar cambios en el color del tema
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                MainTabView()
                    .onAppear {
                        // Configurar permisos de acceso a archivos
                        print("Configurando permisos de acceso a archivos")
                    }
                    .disabled(loadingManager.isLoading) // Deshabilitar interacciones durante la carga
                
                // Overlay de carga simple y efectivo
                if loadingManager.isLoading {
                    ZStack {
                        // Fondo oscuro semi-transparente que cubre toda la pantalla
                        Rectangle()
                            .fill(Color.black.opacity(0.7))
                            .edgesIgnoringSafeArea(.all)
                            .transition(.opacity)
                        
                        // Partículas flotantes
                        ForEach(0..<20) { index in
                            ParticleView(size: CGFloat.random(in: 3...6),
                                        position: CGPoint(x: CGFloat.random(in: -150...150), 
                                                        y: CGFloat.random(in: -200...200)),
                                        color: Color.appTheme().opacity(CGFloat.random(in: 0.5...1.0)),
                                        isAnimating: isAnimating)
                        }
                        
                        // Panel central con indicador de carga
                        VStack(spacing: 20) {
                            // Animación personalizada
                            ZStack {
                                Circle()
                                    .stroke(Color.appTheme().opacity(0.3), lineWidth: 8)
                                    .frame(width: 80, height: 80)
                                
                                Circle()
                                    .trim(from: 0, to: 0.7)
                                    .stroke(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.appTheme().opacity(0.7), Color.appTheme(), Color.appTheme()]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                                    )
                                    .frame(width: 80, height: 80)
                                    .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
                                    .animation(Animation.linear(duration: 1).repeatForever(autoreverses: false), value: isAnimating)
                                
                                Image(systemName: "book.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(.white)
                                    .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
                                    .animation(Animation.linear(duration: 2).repeatForever(autoreverses: false), value: isAnimating)
                            }
                            .onAppear {
                                isAnimating = true
                            }
                            .padding(.bottom, 10)
                            
                            // Texto informativo con gradiente
                            Text("Importando títulos...")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundStyle(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.appTheme().opacity(0.7), Color.appTheme()]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                            
                            Text("Por favor, espera un momento")
                                .font(.body)
                                .foregroundColor(.white)
                                .padding(.bottom, 5)
                            
                            // Indicador de pasos de progreso
                            HStack(spacing: 15) {
                                ForEach(0..<3) { index in
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: [Color.appTheme().opacity(0.7), Color.appTheme()]),
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: 8, height: 8)
                                        .opacity(Double(index) / 2 + 0.3)
                                        .scaleEffect(1.0 - Double(index) * 0.2)
                                        .animation(
                                            Animation
                                                .easeInOut(duration: 0.6)
                                                .repeatForever()
                                                .delay(Double(index) * 0.2),
                                            value: loadingManager.isLoading
                                        )
                                }
                            }
                        }
                        .padding(30)
                        .background(
                            ZStack {
                                // Fondo base con efecto de cristal
                                RoundedRectangle(cornerRadius: 25)
                                    .fill(Color(UIColor.systemBackground).opacity(0.85))
                                
                                // Efecto de brillo en las esquinas
                                RoundedRectangle(cornerRadius: 25)
                                    .fill(
                                        RadialGradient(
                                            gradient: Gradient(colors: [Color.appTheme().opacity(0.3), Color.clear]),
                                            center: .topLeading,
                                            startRadius: 0,
                                            endRadius: 150
                                        )
                                    )
                                
                                // Múltiples círculos pulsantes con diferentes colores
                                ZStack {
                                    // Círculo principal
                                    Circle()
                                        .fill(Color.appTheme().opacity(0.15))
                                        .frame(width: 120, height: 120)
                                        .scaleEffect(scaleAmount)
                                        .blur(radius: 8)
                                        .animation(
                                            Animation
                                                .easeInOut(duration: 1.5)
                                                .repeatForever(autoreverses: true)
                                                .delay(0.2),
                                            value: scaleAmount
                                        )
                                    
                                    // Círculo secundario
                                    Circle()
                                        .fill(Color.appTheme().opacity(0.15))
                                        .frame(width: 100, height: 100)
                                        .scaleEffect(scaleAmount)
                                        .blur(radius: 5)
                                        .animation(
                                            Animation
                                                .easeInOut(duration: 1.5)
                                                .repeatForever(autoreverses: true),
                                            value: scaleAmount
                                        )
                                    
                                    // Círculo terciario
                                    Circle()
                                        .fill(Color.appTheme().opacity(0.15))
                                        .frame(width: 80, height: 80)
                                        .scaleEffect(scaleAmount)
                                        .blur(radius: 3)
                                        .animation(
                                            Animation
                                                .easeInOut(duration: 1.5)
                                                .repeatForever(autoreverses: true)
                                                .delay(0.4),
                                            value: scaleAmount
                                        )
                                }
                                .onAppear {
                                    scaleAmount = 1.3
                                }
                            }
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 25)
                                .stroke(
                                    LinearGradient(
                                        gradient: Gradient(colors: [.cyan, .blue, Color(red: 0.1, green: 0.4, blue: 0.8)]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                        )
                        .shadow(color: Color.blue.opacity(0.5), radius: 15)
                        .transition(.scale.combined(with: .opacity))
                    }
                    .animation(.easeInOut(duration: 0.3), value: loadingManager.isLoading)
                }
            }
            .preferredColorScheme(selectedColorScheme)
        }
    }
    
    // Determinar el esquema de color según la preferencia del usuario
    private var selectedColorScheme: ColorScheme? {
        switch colorScheme {
        case 0:
            return nil // Sistema
        case 1:
            return .light // Claro
        case 2:
            return .dark // Oscuro
        default:
            return nil
        }
    }
}

// Vista para partículas flotantes en la animación de carga
struct ParticleView: View {
    let size: CGFloat
    let position: CGPoint
    let color: Color
    let isAnimating: Bool
    
    @State private var yOffset: CGFloat = 0
    @State private var opacity: Double = 0
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .offset(x: position.x, y: position.y + yOffset)
            .opacity(opacity)
            .onAppear {
                // Valor inicial aleatorio
                opacity = Double.random(in: 0.3...0.7)
                
                // Animar la posición vertical
                withAnimation(
                    Animation
                        .easeInOut(duration: Double.random(in: 2...4))
                        .repeatForever(autoreverses: true)
                ) {
                    yOffset = CGFloat.random(in: -30...30)
                }
                
                // Animar la opacidad
                withAnimation(
                    Animation
                        .easeInOut(duration: Double.random(in: 1...3))
                        .repeatForever(autoreverses: true)
                ) {
                    opacity = Double.random(in: 0.1...0.5)
                }
            }
    }
}
