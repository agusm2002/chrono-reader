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
        return true
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
                                        color: [Color.blue, Color.cyan, Color(red: 0.2, green: 0.6, blue: 0.9)][index % 3],
                                        isAnimating: isAnimating)
                        }
                        
                        // Panel central con indicador de carga
                        VStack(spacing: 20) {
                            // Animación personalizada
                            ZStack {
                                Circle()
                                    .stroke(Color.blue.opacity(0.3), lineWidth: 8)
                                    .frame(width: 80, height: 80)
                                
                                Circle()
                                    .trim(from: 0, to: 0.7)
                                    .stroke(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.cyan, Color.blue, Color(red: 0.1, green: 0.5, blue: 0.9)]),
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
                                        gradient: Gradient(colors: [Color.cyan, Color.blue]),
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
                                                gradient: Gradient(colors: [Color.cyan, Color.blue]),
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
                                            gradient: Gradient(colors: [Color.cyan.opacity(0.3), Color.clear]),
                                            center: .topLeading,
                                            startRadius: 0,
                                            endRadius: 150
                                        )
                                    )
                                
                                // Múltiples círculos pulsantes con diferentes colores
                                ZStack {
                                    // Círculo azul claro
                                    Circle()
                                        .fill(Color.cyan.opacity(0.15))
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
                                    
                                    // Círculo azul medio
                                    Circle()
                                        .fill(Color.blue.opacity(0.15))
                                        .frame(width: 100, height: 100)
                                        .scaleEffect(scaleAmount)
                                        .blur(radius: 5)
                                        .animation(
                                            Animation
                                                .easeInOut(duration: 1.5)
                                                .repeatForever(autoreverses: true),
                                            value: scaleAmount
                                        )
                                    
                                    // Círculo azul oscuro
                                    Circle()
                                        .fill(Color(red: 0.1, green: 0.4, blue: 0.8).opacity(0.15))
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
